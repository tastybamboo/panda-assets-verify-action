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
        compile_propshaft
        copy_engine_js
        generate_importmap
      end

      private

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

              # Create detailed error message
              error_msg = format_error(
                "assets:precompile failed with exit code #{$?.exitstatus}",
                operation: "Asset Compilation",
                command: cmd,
                path: dummy_root,
                hint: "Check that all assets are valid and dependencies are installed"
              )

              summary.add_prepare_error("assets:precompile failed (exit #{$?.exitstatus})")
              summary.add_prepare_log(error_msg)
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

      def copy_engine_js
        src_root  = File.join(host_root, "app/javascript/panda")
        dest_root = File.join(dummy_root, "app/javascript/panda")

        unless Dir.exist?(src_root)
          summary.add_prepare_log("No engine JS found at #{src_root}, skipping JS copy")
          return
        end

        FileUtils.mkdir_p(dest_root)
        FileUtils.cp_r(Dir[File.join(src_root, "*")], dest_root)

        summary.add_prepare_log("Copied JS from #{src_root} → #{dest_root}")
      rescue => e
        error_msg = format_error(
          "#{e.class}: #{e.message}",
          operation: "JavaScript File Copy",
          path: src_root,
          hint: "Ensure source files exist and have proper permissions"
        )

        summary.add_prepare_error("Error copying JS: #{e.class}: #{e.message}")
        summary.add_prepare_log(error_msg)
        summary.mark_prepare_failed!
      end

      def generate_importmap
        summary.add_prepare_log("Generating importmap.json from dummy Rails app")

        t = Benchmark.realtime do
          UI.with_spinner("Loading Rails environment and generating importmap") do
            Dir.chdir(dummy_root) do
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
        error_msg = format_error(
          "#{e.class}: #{e.message}",
          operation: "Importmap Generation",
          file: "config/importmap.rb",
          path: dummy_root,
          hint: "Check that Rails environment loads correctly and importmap-rails is installed"
        )

        summary.add_prepare_error("Error generating importmap.json: #{e.class}: #{e.message}")
        summary.add_prepare_log(error_msg)
        summary.mark_prepare_failed!
      end
    end
  end
end
