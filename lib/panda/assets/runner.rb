# frozen_string_literal: true
require "pathname"

ROOT = Pathname.new(__dir__).expand_path
$LOAD_PATH.unshift(ROOT.to_s)

require "benchmark"
require_relative "ui"
require_relative "summary"
require_relative "html_report"
require_relative "preparer"
require_relative "verifier"

module Panda
  module Assets
    class Runner
      #
      # --- CLASS API FOR GITHUB ACTIONS ---
      #
      class << self
        # Example usage in GitHub Action:
        #   Panda::Assets::Runner.run_all!(dummy_root: "/path/to/dummy")
        def run_all!(dummy_root:)
          new(dummy_root:).run_all!
        end
      end

      #
      # --- INITIALIZER ---
      #
      def initialize(dummy_root:)
        @dummy_root = File.expand_path(dummy_root)
        @summary = Summary.new
      end

      attr_reader :summary

      #
      # --- MAIN PIPELINE ---
      #
      def run_all!
        UI.banner("Prepare Panda Assets")
        prepare_phase

        UI.banner("Verify Panda Assets")
        verify_phase

      ensure
        # Always print console summary
        summary.to_stdout!

        # Always write HTML report
        report_path = File.join(@dummy_root, "tmp", "panda_assets_report.html")
        FileUtils.mkdir_p(File.dirname(report_path))
        HTMLReport.write!(summary, report_path)
      end

      #
      # --- PREPARE PHASE ---
      #
      def prepare_phase
        UI.step("Compiling Propshaft assets")

        propshaft_t = Benchmark.realtime do
          begin
            Preparer.new(dummy_root: @dummy_root, summary: summary).run
          rescue => e
            summary.prepare_log << "EXCEPTION: #{e.message}\n"
            summary.mark_prepare_failed!
          end
        end

        summary.prepare_log << "Prepare phase completed in #{propshaft_t.round(2)}s\n"

        if summary.failed?
          UI.error("Prepare phase FAILED")
        else
          UI.ok("Compiled propshaft assets")
        end
      end

      #
      # --- VERIFY PHASE ---
      #
      def verify_phase
        begin
          Verifier.new(dummy_root: @dummy_root, summary: summary).run
        rescue => e
          summary.verify_log << "EXCEPTION: #{e.message}\n"
          summary.mark_verify_failed!
        end
      end
    end
  end
end
