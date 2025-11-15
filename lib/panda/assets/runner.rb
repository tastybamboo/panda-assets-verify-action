# frozen_string_literal: true

require "pathname"
require "benchmark"
require "fileutils"

require_relative "ui"
require_relative "summary"
require_relative "html_report"
require_relative "markdown_summary"
require_relative "preparer"
require_relative "verifier"

module Panda
  module Assets
    class Runner
      include UI

      class << self
        # Used by the GitHub Action
        #
        #   Panda::Assets::Runner.run_all!(dummy_root: "/path/to/spec/dummy")
        #
        def run_all!(dummy_root:)
          new(dummy_root:).run_all!
        end
      end

      attr_reader :dummy_root, :summary

      def initialize(dummy_root:)
        @dummy_root = File.expand_path(dummy_root)
        @summary    = Summary.new
      end

      # Main pipeline: prepare + verify + report
      #
      # - Never raises for asset problems
      # - Always writes HTML + JSON reports
      # - Returns true/false for CI exit code
      #
      def run_all!
        # In GitHub Actions, redirect UI output to stderr to avoid interfering with outputs
        original_stdout = nil
        if ENV["GITHUB_ACTIONS"] == "true"
          original_stdout = $stdout
          $stdout = $stderr
        end

        UI.banner("Prepare Panda Assets")

        begin
          prepare!
        rescue => e
          summary.add_prepare_error("Exception in prepare!: #{e.class}: #{e.message}")
        end

        UI.banner("Verify Panda Assets")

        begin
          verify!
        rescue => e
          summary.add_verify_error("Exception in verify!: #{e.class}: #{e.message}")
        end

      ensure
        # Emit console summary for humans
        begin
          summary.to_stdout!
        rescue => e
          puts "Error writing summary to stdout: #{e.message}"
        end

        # Always write reports
        tmp_dir      = File.join(dummy_root, "tmp")
        FileUtils.mkdir_p(tmp_dir) unless Dir.exist?(tmp_dir)

        html_path    = File.join(tmp_dir, "panda_assets_report.html")
        json_path    = File.join(tmp_dir, "panda_assets_summary.json")
        md_path      = File.join(tmp_dir, "panda_assets_summary.md")

        # Write HTML report with error handling
        begin
          HTMLReport.write!(summary, html_path)
        rescue => e
          puts "Error writing HTML report: #{e.message}"
          # Write a minimal error report
          File.write(html_path, "<html><body><h1>Error generating report</h1><pre>#{e.message}\n#{e.backtrace.join("\n")}</pre></body></html>")
        end

        # Write JSON with error handling
        begin
          summary.write_json!(json_path)
        rescue => e
          puts "Error writing JSON summary: #{e.message}"
          # Write minimal JSON
          File.write(json_path, '{"error": "Failed to generate summary", "message": "' + e.message.gsub('"', '\\"') + '"}')
        end

        # Write Markdown summary for GitHub Actions
        begin
          MarkdownSummary.write!(summary, md_path)
        rescue => e
          puts "Error writing Markdown summary: #{e.message}"
          # Write minimal markdown
          File.write(md_path, "# Error\n\nFailed to generate summary: #{e.message}")
        end

        # Restore original stdout if we redirected it
        $stdout = original_stdout if original_stdout
      end

      # Prepare phase: compile + copy JS + importmap
      def prepare!
        t_total = Benchmark.realtime do
          preparer = Preparer.new(dummy_root: dummy_root, summary: summary)
          preparer.run
        end
        summary.timings[:prepare_total] = t_total
      end

      # Verify phase: manifest + importmap + HTTP checks
      def verify!
        t_total = Benchmark.realtime do
          verifier = Verifier.new(dummy_root: dummy_root, summary: summary)
          verifier.run
        end
        summary.timings[:verify_total] = t_total
      end
    end
  end
end

# --- CLI entrypoint when called directly ---
if $PROGRAM_NAME == __FILE__
  dummy_root = nil
  args = ARGV.dup

  while (arg = args.shift)
    case arg
    when "--dummy"
      dummy_root = args.shift
    else
      warn "Unknown argument: #{arg}"
    end
  end

  unless dummy_root
    warn "Usage: #{$PROGRAM_NAME} --dummy PATH/TO/spec/dummy"
    exit 1
  end

  runner = Panda::Assets::Runner.new(dummy_root: dummy_root)
  runner.run_all!

  exit(runner.summary.failed? ? 1 : 0)
end
