# frozen_string_literal: true

require "benchmark"

module Panda
  module Assets
    class Preparer
      include UI

      def initialize(summary)
        @summary = summary
      end

      def run!
        UI.banner("Prepare Panda Assets")

        t = Benchmark.realtime do
          compile_propshaft
          copy_engine_js
          generate_importmap
        end

        @summary.record_time(:prepare_total, t)
      end

      private

      def dummy_root
        ENV["dummy_root"] || "spec/dummy"
      end

      def compile_propshaft
        UI.step("Compiling Propshaft assets")
        ok = system("cd #{dummy_root} && bundle exec rails assets:precompile RAILS_ENV=test")
        @summary.record_prepare(:propshaft_compile, ok)
        UI.ok("Compiled propshaft assets") if ok
        UI.error("Propshaft failed") unless ok
      end

      def copy_engine_js
        UI.step("Copying engine JS")
        core_src = File.expand_path("../../../app/javascript/panda/core", __dir__)
        dest = File.join(dummy_root, "app/javascript/panda/core")
        FileUtils.mkdir_p(dest)
        ok = FileUtils.cp_r(Dir["#{core_src}/*"], dest) rescue false
        @summary.record_prepare(:copy_js, ok)
        ok ? UI.ok("Copied JS") : UI.error("Could not copy JS")
      end

      def generate_importmap
        UI.step("Generating importmap.json")
        ok = system("cd #{dummy_root} && bundle exec rails runner 'puts Rails.application.importmap.to_json(resolver: ActionController::Base.helpers)' > public/assets/importmap.json")
        @summary.record_prepare(:importmap_generate, ok)
        ok ? UI.ok("Generated importmap") : UI.error("importmap.json failed")
      end
    end
  end
end
