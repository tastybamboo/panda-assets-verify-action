# frozen_string_literal: true
require "pathname"

ROOT = Pathname.new(__dir__).expand_path
$LOAD_PATH.unshift(ROOT.to_s)

require "benchmark"
require_relative "ui"
require_relative "summary"
require_relative "html_report"
require_relative "json_summary"
require_relative "preparer"
require_relative "verifier"

module Panda
  module Assets
    class Runner
      class << self
        def run_all!(dummy_root:)
          new(dummy_root:).run_all!
        end
      end

      def initialize(dummy_root:)
        @dummy_root = File.expand_path(dummy_root)
        @summary = Summary.new
      end

      attr_reader :summary

      def run_all!
        UI.banner("Prepare Panda Assets")

        begin
          prepare!
        rescue => e
          summary.add_error("prepare_exception", e.message)
        end

        UI.banner("Verify Panda Assets")

        begin
          verify!
        rescue => e
          summary.add_error("verify_exception", e.message)
        end

      ensure
        summary.to_stdout!

        report_path = File.join(@dummy_root, "tmp", "panda_assets_report.html")
        HTMLReport.write!(summary, report_path)

        json_path = File.join(@dummy_root, "tmp", "panda_assets_summary.json")
        JSONSummary.write!(summary, json_path)
      end

      def prepare!
        UI.step("Compiling Propshaft assets")

        t = Benchmark.realtime do
          Preparer.new(dummy_root: @dummy_root, summary: @summary).run
        end

        summary.timings[:prepare] = t
        UI.ok("Compiled propshaft assets") if summary.prepare_ok?
      end

      def verify!
        Verifier.new(dummy_root: @dummy_root, summary: @summary).run
      end
    end
  end
end
