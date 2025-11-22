# frozen_string_literal: true

require "benchmark"
require "fileutils"
require_relative "error_helper"

module Panda
  module Assets
    class Preparer
      include UI
      include ErrorHelper

      attr_reader :dummy_root, :summary

      def initialize(dummy_root:, summary:)
        @dummy_root = File.expand_path(dummy_root)
        @summary    = summary
      end

      def host_root
        # e.g. /path/to/panda-core when dummy_root is /path/to/panda-core/spec/dummy
        File.expand_path("../..", dummy_root)
      end

      def run
        compile_css
        stage_panda_assets
        compile_propshaft
        copy_engine_js
        generate_importmap
      end

      private

      def compile_css
        summary.add_prepare_log("Compiling Panda CSS for all registered modules")

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # Run from the host root (the gem directory) to ensure proper Rails environment
        Dir.chdir(host_root) do
          # Try app:panda:compile_css first (works from gem root)
          # Fall back to panda:compile_css if needed (works from spec/dummy)
          cmd = "bundle exec rake app:panda:compile_css 2>&1 || bundle exec rake panda:compile_css 2>&1"

          spinner = UI::Spinner.new("Compiling CSS (this scans all Panda module files)")
          spinner.start

          output = `#{cmd}`
          ok = $?.success?

          if ok
            spinner.stop(success: true, final_message: "CSS compiled successfully")

            # Check if CSS file was actually created
            css_file = Dir.glob(File.join(host_root, "public/panda-*-assets/panda-*.css")).first
            if css_file
              file_size = (File.size(css_file) / 1024.0).round(1)
              summary.add_prepare_log("✅ CSS file generated: #{File.basename(css_file)} (#{file_size} KB)")
            else
              summary.add_prepare_log("⚠️  CSS compilation succeeded but no CSS file found in public/")
            end
          else
            spinner.stop(success: false, final_message: "CSS compilation failed")

            summary.add_prepare_error("CSS compilation failed (exit #{$?.exitstatus})")
            summary.add_prepare_log("Command: #{cmd}")
            summary.add_prepare_log("Path: #{host_root}")
            summary.add_prepare_log("\nCommand output:\n#{output}")
            summary.mark_prepare_failed!
            return
          end
        end

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        summary.timings[:prepare_css] = elapsed
        summary.add_prepare_log("CSS compiled in #{elapsed.round(2)}s")
      rescue => e
        summary.add_prepare_error("Error compiling CSS: #{e.class}: #{e.message}")
        summary.add_prepare_log("Host root: #{host_root}")
        summary.add_prepare_log("Error: #{e.message}")
        summary.add_prepare_log("Backtrace:\n#{e.backtrace.join("\n")}")
        summary.mark_prepare_failed!
      end

      def stage_panda_assets
        summary.add_prepare_log("Copying compiled Panda assets into dummy/public")

        source_dir = locate_panda_core_assets

        unless source_dir && Dir.exist?(source_dir)
          summary.add_prepare_log("⚠️  Unable to find panda-core assets directory. Skipping copy.")
          return
        end

        dest_dir = File.join(dummy_root, "public", "panda-core-assets")
        FileUtils.mkdir_p(dest_dir)

        # Copy everything (CSS, JS, manifest files) to ensure Rails can serve them
        FileUtils.cp_r(Dir[File.join(source_dir, "*")], dest_dir, remove_destination: true)

        copied_files = Dir.glob(File.join(dest_dir, "**/*")).select { |f| File.file?(f) }
        summary.add_prepare_log("✅ Copied #{copied_files.size} panda-core asset file(s) to #{dest_dir}")

        css_files = copied_files.select { |f| File.extname(f) == ".css" }
        if css_files.empty?
          summary.add_prepare_log("⚠️  No CSS files were copied into #{dest_dir}")
        else
          sample = css_files.first
          size_kb = (File.size(sample) / 1024.0).round(1)
          summary.add_prepare_log("   Example CSS file: #{File.basename(sample)} (#{size_kb} KB)")
        end
      rescue => e
        summary.add_prepare_error("Error copying panda-core assets: #{e.class}: #{e.message}")
        summary.add_prepare_log("Source path: #{source_dir || "unknown"}")
        summary.add_prepare_log("Backtrace:\n#{e.backtrace.join("\n")}")
        summary.mark_prepare_failed!
      end

      def compile_propshaft
        summary.add_prepare_log("Compiling Propshaft assets in dummy app")

        t = Benchmark.realtime do
          Dir.chdir(dummy_root) do
            cmd = "bundle exec rails assets:precompile RAILS_ENV=test"

            # Show spinner during compilation
            spinner = UI::Spinner.new("Compiling assets (this may take a moment)")
            spinner.start

            # Capture output to avoid cluttering the display
            output = `#{cmd} 2>&1`
            ok = $?.success?

            if ok
              spinner.stop(success: true, final_message: "Assets compiled successfully")
            else
              spinner.stop(success: false, final_message: "Asset compilation failed")

              summary.add_prepare_error("assets:precompile failed (exit #{$?.exitstatus})")
              summary.add_prepare_log("Command: #{cmd}")
              summary.add_prepare_log("Path: #{dummy_root}")
              summary.add_prepare_log("\nCommand output:\n#{output}")
              summary.mark_prepare_failed!
              return
            end
          end
        end

        summary.timings[:prepare_propshaft] = t
        summary.add_prepare_log("Propshaft assets compiled in #{t.round(2)}s")
        summary.mark_prepare_ok!
      end

      def locate_panda_core_assets
        return File.join(host_root, "public", "panda-core-assets") if Dir.exist?(File.join(host_root, "public", "panda-core-assets"))

        Dir.chdir(host_root) do
          cmd = %(bundle exec ruby -e "begin; require 'panda/core'; puts Panda::Core::Engine.root.join('public/panda-core-assets'); rescue LoadError => e; warn e.message; exit 1; end")
          output = `#{cmd}`
          return nil unless $?.success?

          path = output.split("\n").last&.strip
          return path if path && Dir.exist?(path)
        end

        nil
      rescue => e
        summary.add_prepare_log("Error locating panda-core assets: #{e.class}: #{e.message}")
        nil
      end

      def copy_engine_js
        src_root  = File.join(host_root, "app/javascript/panda")
        dest_root = File.join(dummy_root, "app/javascript/panda")
        public_dest = File.join(dummy_root, "public/panda")

        unless Dir.exist?(src_root)
          summary.add_prepare_log("No engine JS found at #{src_root}, skipping JS copy")
          return
        end

        # List all JS files to be copied for debugging
        js_files = Dir.glob(File.join(src_root, "**/*")).select { |f| File.file?(f) }
        summary.add_prepare_log("Found #{js_files.size} files to copy from #{src_root}")
        js_files.each do |file|
          relative = file.sub(src_root, "")
          summary.add_prepare_log("  - #{relative}")
        end

        # Copy to app/javascript for Rails runtime (ModuleRegistry middleware expects this)
        FileUtils.mkdir_p(dest_root)
        FileUtils.cp_r(Dir[File.join(src_root, "*")], dest_root, remove_destination: true)
        summary.add_prepare_log("✅ Copied JS to app/javascript for runtime: #{src_root} → #{dest_root}")

        # Verify the copy was successful
        copied_runtime = Dir.glob(File.join(dest_root, "**/*")).select { |f| File.file?(f) }
        summary.add_prepare_log("  Verified #{copied_runtime.size} files in #{dest_root}")

        # Also copy to public/panda for static verification
        FileUtils.mkdir_p(public_dest)
        FileUtils.cp_r(Dir[File.join(src_root, "*")], public_dest, remove_destination: true)
        summary.add_prepare_log("✅ Copied JS to public for verification: #{src_root} → #{public_dest}")

        # Verify the public copy was successful
        copied_public = Dir.glob(File.join(public_dest, "**/*")).select { |f| File.file?(f) }
        summary.add_prepare_log("  Verified #{copied_public.size} files in #{public_dest}")
      rescue => e
        summary.add_prepare_error("Error copying JS: #{e.class}: #{e.message}")
        summary.add_prepare_log("Source path: #{src_root}")
        summary.add_prepare_log("Error: #{e.message}")
        summary.add_prepare_log("Backtrace:\n#{e.backtrace.join("\n")}")
        summary.mark_prepare_failed!
      end

      def generate_importmap
        summary.add_prepare_log("Generating importmap.json from dummy Rails app")

        t = Benchmark.realtime do
          UI.with_spinner("Loading Rails environment and generating importmap") do
            Dir.chdir(dummy_root) do
              # Set up Bundler to use the dummy's Gemfile or create a minimal one
              unless File.exist?(File.join(dummy_root, "Gemfile"))
                # Copy our minimal template Gemfile to the dummy app
                template_path = File.expand_path("../../../templates/dummy_gemfile.rb", __FILE__)
                dummy_gemfile = File.join(dummy_root, "Gemfile")

                if File.exist?(template_path)
                  FileUtils.cp(template_path, dummy_gemfile)
                  summary.add_prepare_log("Created minimal Gemfile for dummy app")

                  # Run bundle install with the new Gemfile
                  `cd #{dummy_root} && bundle install --quiet`
                  if $?.success?
                    summary.add_prepare_log("Installed minimal dependencies for dummy app")
                  else
                    summary.add_prepare_log("Warning: bundle install failed for dummy app")
                  end
                else
                  # Fallback to parent Gemfile if template doesn't exist
                  parent_gemfile = File.join(host_root, "Gemfile")
                  if File.exist?(parent_gemfile)
                    ENV['BUNDLE_GEMFILE'] = parent_gemfile
                    summary.add_prepare_log("Using parent Gemfile at #{parent_gemfile}")
                  end
                end
              end

              require File.join(dummy_root, "config/environment")

              importmap = if Rails.application.respond_to?(:importmap)
                Rails.application.importmap
              else
                nil
              end

              unless importmap
                summary.add_prepare_log("No Rails importmap found, skipping importmap.json generation")
                return
              end

              json = if importmap.respond_to?(:to_json)
                importmap.to_json(
                  resolver: ActionController::Base.helpers
                )
              else
                # very old or custom importmap
                JSON.pretty_generate(importmap)
              end

              out_dir = File.join(dummy_root, "public", "assets")
              FileUtils.mkdir_p(out_dir)
              path = File.join(out_dir, "importmap.json")
              File.write(path, json)

              summary.add_prepare_log("Wrote importmap.json → #{path}")
            end
          end
        end

        summary.timings[:prepare_importmap] = t
      rescue => e
        summary.add_prepare_error("Error generating importmap.json: #{e.class}: #{e.message}")
        summary.add_prepare_log("Path: #{dummy_root}")
        summary.add_prepare_log("Error: #{e.message}")
        summary.add_prepare_log("Hint: Check that Rails environment loads correctly and importmap-rails is installed")
        summary.mark_prepare_failed!
      end
    end
  end
end
