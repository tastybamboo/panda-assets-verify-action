# frozen_string_literal: true

require "json"

module Panda
  module Assets
    class MarkdownSummary
      def self.write!(summary, path)
        new(summary).write!(path)
      end

      def initialize(summary)
        @summary = summary
      end

      def write!(path)
        File.write(path, generate_markdown)
      end

      private

      def generate_markdown
        lines = []

        # Header
        lines << "# 🐼 Panda Assets Verification Report"
        lines << ""
        lines << "**Generated:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
        lines << ""

        # Overall Status
        status = @summary.failed? ? "❌ **FAILED**" : "✅ **PASSED**"
        lines << "## Overall Status: #{status}"
        lines << ""

        # Summary Table
        lines << "| Phase | Status | Errors |"
        lines << "|-------|--------|--------|"
        lines << "| Prepare | #{status_badge(@summary.prepare_ok?)} | #{@summary.prepare_errors.size} |"
        lines << "| Verify | #{status_badge(@summary.verify_ok?)} | #{@summary.verify_errors.size} |"
        lines << ""

        # Timing Information
        if @summary.timings.any?
          lines << "## ⏱️ Performance"
          lines << ""
          lines << "| Operation | Time |"
          lines << "|-----------|------|"
          @summary.timings.each do |key, value|
            lines << "| #{key.to_s.gsub('_', ' ').capitalize} | #{format('%.2fs', value)} |"
          end
          lines << ""
        end

        # Errors Section
        if @summary.prepare_errors.any?
          lines << "## ❌ Prepare Errors"
          lines << ""
          @summary.prepare_errors.each_with_index do |error, i|
            lines << "#{i + 1}. #{error}"
          end
          lines << ""
        end

        if @summary.verify_errors.any?
          lines << "## ❌ Verify Errors"
          lines << ""
          @summary.verify_errors.each_with_index do |error, i|
            lines << "#{i + 1}. #{error}"
          end
          lines << ""
        end

        # Missing Assets
        if @summary.diff_missing.any?
          lines << "## 📦 Missing Assets"
          lines << ""
          lines << "<details>"
          lines << "<summary>Click to expand (#{@summary.diff_missing.size} files)</summary>"
          lines << ""
          @summary.diff_missing.each do |file|
            lines << "- `#{file}`"
          end
          lines << ""
          lines << "</details>"
          lines << ""
        end

        # Logs (collapsed by default)
        if @summary.prepare[:log].any?
          lines << "<details>"
          lines << "<summary>📋 Prepare Logs</summary>"
          lines << ""
          lines << "```"
          lines << @summary.prepare[:log].join("\n")
          lines << "```"
          lines << ""
          lines << "</details>"
          lines << ""
        end

        if @summary.verify[:log].any?
          lines << "<details>"
          lines << "<summary>📋 Verify Logs</summary>"
          lines << ""
          lines << "```"
          lines << @summary.verify[:log].join("\n")
          lines << "```"
          lines << ""
          lines << "</details>"
          lines << ""
        end

        lines.join("\n")
      end

      def status_badge(ok)
        ok ? "✅ Pass" : "❌ Fail"
      end
    end
  end
end