# frozen_string_literal: true

require "erb"
require "fileutils"

module Panda
  module Assets
    module HtmlReport
      module_function

      def write!(summary, output_path)
        html = render(summary)

        FileUtils.mkdir_p(File.dirname(output_path))
        File.write(output_path, html)

        puts "📄 HTML report written to: #{output_path}"
      end

      def render(summary)
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <title>Panda Asset Verification Report</title>
            <style>
              body { font-family: system-ui, sans-serif; padding: 2rem; line-height: 1.6; }
              h1 { font-size: 1.8rem; }
              .ok { color: #16a34a; }
              .fail { color: #dc2626; }
              pre { background: #f3f4f6; padding: 1rem; border-radius: .25rem; white-space: pre-wrap; }
            </style>
          </head>
          <body>

            <h1>Panda Asset Verification Report</h1>

            <h2>Status</h2>
            <p class="#{summary.failed? ? "fail" : "ok"}">
              #{summary.failed? ? "FAIL" : "PASS"}
            </p>

            <h2>Preparation Log</h2>
            <pre>#{ERB::Util.html_escape(summary.prepare_log)}</pre>

            <h2>Verification Log</h2>
            <pre>#{ERB::Util.html_escape(summary.verify_log)}</pre>

          </body>
          </html>
        HTML
      end
    end
  end
end
