# frozen_string_literal: true

require "benchmark"
require_relative "ui"
require_relative "preparer"
require_relative "verifier"
require_relative "summary"
require_relative "html_report"

module Panda
  module Assets
    class Runner
      def self.run_all!(dummy_root:)
        new(dummy_root: dummy_root).run_all!
      end

      def initialize(dummy_root:)
        @dummy_root = dummy_root
      end

      def run_all!
        summary = Summary.new

        Preparer.new(dummy_root: @dummy_root, summary: summary).run!
        Verifier.new(dummy_root: @dummy_root, summary: summary).run!

        report_path = File.join(@dummy_root, "tmp", "panda_assets_report.html")
        HtmlReport.write!(summary, report_path)

        raise "Panda asset verification failed" if summary.failed?
      end
    end
  end
end
