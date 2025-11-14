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
      #
      # --- CLASS API FOR GITHUB ACTIONS ---
      #
      class << self
        # API used in the GitHub Action
        #
        #   Panda::Assets::Runner.run_all!(dummy_root: "/path/to/dummy")
        #
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
      # --- MAIN PIPELINE ENTRYPOINT ---
      #
      # Ensures the HTML report *always* gets written even if assets are missing.
      #
      def run_all!
        UI.banner("Prepare Panda Assets")

        begin
          prepare!
        rescue => e
          @summary.add_error("prepare_exception", e.message)
        end

        UI.banner("Verify Panda Assets")

        begin
          verify!
        rescue => e
          @summary.add_error("verify_exception", e.message)
        end

      ensure
        # Always generate the report, even in catastrophic failure.
        HTMLReport.write!(summary, @dummy_root)
      end

      #
      # --- PREPARE PHASE ---
      #
      def prepare!
        UI.step("Compiling Propshaft assets")

        propshaft_t = Benchmark.realtime do
          Preparer.new(dummy_root: @dummy_root, summary: @summary).run
        end

        summary.timings[:prepare_propshaft] = propshaft_t
        UI.ok("Compiled propshaft assets") if summary.prepare_ok?

        # Even on failure, continue — verification may reveal more problems.
        true
      end

      #
      # --- VERIFY PHASE ---
      #
      def verify!
        verifier = Verifier.new(dummy_root: @dummy_root, summary: @summary)
        verifier.run
      end
    end
  end
end
