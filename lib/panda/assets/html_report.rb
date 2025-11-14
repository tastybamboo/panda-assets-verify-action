# frozen_string_literal: true

require "erb"
require "fileutils"

module Panda
  module Assets
    class HTMLReport
      TEMPLATE = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Panda Asset Verification</title>
          <style>
            body { font-family: sans-serif; margin: 40px; }
            .section { padding: 20px; border-radius: 8px; margin-bottom: 32px; border: 1px solid #ddd; }
            h1 { font-size: 28px; }
            h2 { font-size: 20px; margin-bottom: 10px; }
            pre { background: #f8f8f8; padding: 12px; border-radius: 6px; overflow-x: auto; }
            .ok { color: #059669; font-weight: bold; }
            .fail { color: #dc2626; font-weight: bold; }
          </style>
        </head>
        <body>
          <h1>Panda Asset Verification Report</h1>

          <div class="section">
            <h2>Result</h2>
            <p class="<%= summary.failed? ? "fail" : "ok" %>">
              <%= summary.failed? ? "FAIL" : "PASS" %>
            </p>
          </div>

          <div class="section">
            <h2>Prepare Phase</h2>
            <pre><%= summary.prepare_log %></pre>
          </div>

          <div class="section">
            <h2>Verify Phase</h2>
            <pre><%= summary.verify_log %></pre>
          </div>
        </body>
        </html>
      HTML

      def self.write!(summary, output_path)
        FileUtils.mkdir_p(File.dirname(output_path))
        html = ERB.new(TEMPLATE).result(binding)
        File.write(output_path, html)
      end
    end
  end
end
