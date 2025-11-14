# frozen_string_literal: true

module Panda
  module Assets
    class HTMLReport
      def self.write!(summary)
        html = new(summary).render
        File.write("panda-assets-report.html", html)
      end

      def initialize(summary)
        @summary = summary
      end

      def render
        <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Panda Asset Verification</title>
          <style>
            body { font-family: -apple-system, sans-serif; margin: 2rem; }
            .ok { color: #16a34a; }
            .fail { color: #dc2626; font-weight: bold; }
            .section { margin-bottom: 2rem; }
            .heading { font-size: 1.4rem; font-weight: 600; margin-bottom: .5rem; }
            .code { font-family: monospace; background: #f3f4f6; padding: 4px 6px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <h1>Panda Asset Verification</h1>

          <div class="section">
            <div class="heading">Prepare Phase</div>
            #{render_checks(@summary.prepare_checks)}
          </div>

          <div class="section">
            <div class="heading">Verify Phase</div>
            #{render_checks(@summary.verify_checks)}
          </div>

          <div class="section">
            <div class="heading">Timings</div>
            <ul>
              #{render_timings}
            </ul>
          </div>

          <p>Status: <span class="#{@summary.failed? ? 'fail' : 'ok'}">#{@summary.failed? ? "FAILED" : "OK"}</span></p>
        </body>
        </html>
        HTML
      end

      def render_checks(checks)
        list = checks.map do |k, ok|
          "<li>#{k}: <span class='#{ok ? "ok" : "fail"}'>#{ok ? "OK" : "FAIL"}</span></li>"
        end.join("\n")

        "<ul>#{list}</ul>"
      end

      def render_timings
        @summary.timings.map { |k, t| "<li>#{k}: #{t.round(2)}s</li>" }.join("\n")
      end
    end
  end
end
