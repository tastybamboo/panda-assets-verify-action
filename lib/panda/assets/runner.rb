# frozen_string_literal: true

# Add lib/ to load path when run ad-hoc
$LOAD_PATH.unshift(File.expand_path("../../..", __dir__))

require "benchmark"
require "optparse"
require_relative "ui"
require_relative "preparer"
require_relative "verifier"
require_relative "summary"
require_relative "html_report"

module Panda
  module Assets
    class Runner
      include UI

      def self.run_all!(argv = ARGV)
        new.run_all!(argv)
      end

      def initialize
        @dummy_root = "spec/dummy"
      end

      def run_all!(argv = ARGV)
        parse_options!(argv)

        Dir.chdir(ENV["GITHUB_WORKSPACE"]) if ENV["GITHUB_WORKSPACE"]

        summary = Summary.new

        Preparer.new(summary).run!
        Verifier.new(summary).run!

        report_path = File.join(@dummy_root, "tmp", "panda_assets_report.html")
        HTMLReport.write!(summary, report_path)

        if summary.failed?
          UI.error("Panda asset pipeline FAILED")
          exit 1
        else
          UI.ok("Panda asset pipeline OK")
          exit 0
        end
      end

      private

      def parse_options!(argv)
        OptionParser.new do |opts|
          opts.banner = "Usage: runner.rb [options]"

          opts.on("--dummy PATH", "Path to dummy Rails app (default: spec/dummy)") do |path|
            @dummy_root = path
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            exit
          end
        end.parse!(argv)
      end
    end
  end
end

# Run if called directly
if __FILE__ == $0
  Panda::Assets::Runner.run_all!
end
