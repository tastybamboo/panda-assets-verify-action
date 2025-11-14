# frozen_string_literal: true
require "pathname"

ROOT = Pathname.new(__dir__).expand_path
$LOAD_PATH.unshift(ROOT.to_s)

# lib/panda/assets/runner.rb
# frozen_string_literal: true

require "benchmark"
require_relative "ui"
require_relative "summary"
require_relative "html_report"
require_relative "preparer"
require_relative "verifier"

module Panda
  module Assets
    class Runner
      def self.run_all!(dummy_root:)
        new(dummy_root:).run_all!
      end

      def initialize(dummy_root:)
        @dummy_root = File.expand_path(dummy_root)
        @summary = Summary.new
      end

      def run_all!
        begin
          UI.banner("Prepare Panda Assets")
          prepare!
        rescue => e
          @summary.add_prepare_error("Exception: #{e.message}")
        end

        begin
          UI.banner("Verify Panda Assets")
          verify!
        rescue => e
          @summary.add_verify_error("Exception: #{e.message}")
        end

      ensure
        write_outputs!
      end

      def prepare!
        Preparer.new(dummy_root: @dummy_root, summary: @summary).run
      end

      def verify!
        Verifier.new(dummy_root: @dummy_root, summary: @summary).run
      end

      def write_outputs!
        json_path   = File.join(@dummy_root, "tmp/panda_assets_summary.json")
        report_path = File.join(@dummy_root, "tmp/panda_assets_report.html")

        @summary.write_json!(json_path)
        HTMLReport.write!(@summary, report_path)

        UI.banner("Final Result", status: @summary.failed? ? :fail : :ok)
      end
    end
  end
end
