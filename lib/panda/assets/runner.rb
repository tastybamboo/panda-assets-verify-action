# frozen_string_literal: true

# Add lib/ to load path when run ad-hoc
$LOAD_PATH.unshift(File.expand_path("../../..", __dir__))

require "benchmark"
require_relative "ui"
require_relative "preparer"
require_relative "verifier"
require_relative "summary"
require_relative "html_report"

module Panda
  module Assets
    class Runner
      include UI

      def self.run_all!
        new.run_all!
      end

      def run_all!
        summary = Summary.new

        Preparer.new(summary).run!
        Verifier.new(summary).run!

        HTMLReport.write!(summary)

        if summary.failed?
          UI.error("Panda asset pipeline FAILED")
          exit 1
        else
          UI.ok("Panda asset pipeline OK")
          exit 0
        end
      end
    end
  end
end
