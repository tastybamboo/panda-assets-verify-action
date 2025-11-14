# frozen_string_literal: true

require "erb"
require "fileutils"

module Panda
  module Assets
    class HTMLReport
      TEMPLATE = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <title>Panda Asset Verification Report</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; margin: 2rem; }
            h1 { font-size: 1.6rem; margin-bottom: 1rem; }
            h2 { font-size: 1.3rem; margin-top: 2rem; }
            .ok { color: #0a0; }
            .fail { color: #c00; }
            table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
            th, td { border: 1px solid #ddd; padding: 0.5rem; }
            th { background: #f8f8f8; text-align: left; }
            .section { margin-bottom: 2rem; }
          </style>
        </head>
        <body>
          <h1>Panda Asset Verification Report</h1>

          <div class="section">
            <h2>Overall Status</h2>
            <p>
              <% if summary.failed? %>
                <strong class="fail">FAIL</strong>
              <% else %>
                <strong class="ok">PASS</strong>
              <% end %>
            </p>
          </div>

          <div class="section">
            <h2>Summary</h2>
            <table>
              <thead>
                <tr><th>Category</th><th>Status</th></tr>
              </thead>
              <tbody>
                <% summary.categories.each do |category, status| %>
                  <tr>
                    <td><%= category %></td>
                    <td class="<%= status ? "ok" : "fail" %>">
                      <%= status ? "OK" : "FAIL" %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="section">
            <h2>Errors</h2>
            <% if summary.errors.empty? %>
              <p class="ok">No errors.</p>
            <% else %>
              <ul>
                <% summary.errors.each do |err| %>
                  <li class="fail"><%= err %></li>
                <% end %>
              </ul>
            <% end %>
          </div>

          <div class="section">
            <h2>Timings</h2>
            <table>
              <thead>
                <tr><th>Step</th><th>Seconds</th></tr>
              </thead>
              <tbody>
                <% summary.timings.each do |key, sec| %>
                  <tr>
                    <td><%= key %></td>
                    <td><%= "%0.2f" % sec %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

        </body>
        </html>
      HTML

      #
      # Write HTML file to tmp/panda_assets_report.html under the dummy root
      #
      def self.write!(summary, dummy_root)
        out_dir  = File.join(dummy_root, "tmp")
        out_file = File.join(out_dir, "panda_assets_report.html")

        FileUtils.mkdir_p(out_dir)

        html = ERB.new(TEMPLATE).result(binding)

        File.write(out_file, html)

        puts "📄 HTML report written to #{out_file}"
      end
    end
  end
end
