# frozen_string_literal: true

require "fileutils"

module Panda
  module Assets
    class Preparer
      def initialize(dummy_root:, summary:)
        @dummy_root = dummy_root
        @summary = summary

        @dummy_app = File.expand_path(dummy_root)
        @public_assets = File.join(@dummy_app, "public", "panda-core-assets")
        @dummy_js = File.join(@dummy_app, "app", "javascript", "panda", "core")
      end

      def run
        compile_propshaft!
        copy_js!
        generate_importmap!
      end

      private

      #
      # 1. Compile Propshaft (Ruby-only — no Node needed)
      #
      def compile_propshaft!
        out = +""

        Dir.chdir(@dummy_app) do
          out << `bundle exec rails assets:clobber 2>&1`
          out << `bundle exec rails assets:precompile 2>&1`
        end

        @summary.prepare_log << out

        unless Dir.exist?(@public_assets)
          @summary.prepare_log << "ERROR: No compiled assets found\n"
          @summary.mark_prepare_failed!
        end
      end

      #
      # 2. Copy JS from engine -> dummy
      #
      def copy_js!
        engine_js = File.expand_path("../../../../app/javascript/panda/core", __dir__)

        unless Dir.exist?(engine_js)
          @summary.prepare_log << "WARNING: Engine JS not found at #{engine_js}\n"
          return
        end

        FileUtils.mkdir_p(@dummy_js)
        FileUtils.cp_r("#{engine_js}/.", @dummy_js)

        @summary.prepare_log << "Copied JS from #{engine_js} to #{@dummy_js}\n"
      rescue => e
        @summary.prepare_log << "ERROR copying JS: #{e.message}\n"
        @summary.mark_prepare_failed!
      end

      #
      # 3. Generate importmap.json inside dummy app
      #
      def generate_importmap!
        importmap_path = File.join(@dummy_app, "public", "assets", "importmap.json")
        FileUtils.mkdir_p(File.dirname(importmap_path))

        importmap_hash = {
          imports: {
            "panda-core/application" => "/panda/core/application.js"
          }
        }

        File.write(importmap_path, JSON.pretty_generate(importmap_hash))

        @summary.prepare_log << "Generated importmap.json\n"
      rescue => e
        @summary.prepare_log << "ERROR generating importmap.json: #{e.message}\n"
        @summary.mark_prepare_failed!
      end
    end
  end
end
