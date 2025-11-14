# frozen_string_literal: true

require "webrick"
require "net/http"
require "json"

module Panda
  module Assets
    class Verifier
      def initialize(dummy_root:, summary:)
        @dummy_root = dummy_root
        @summary = summary
      end

      #
      # Run a tiny static-file WEBrick server and test key assets
      #
      def run
        @summary.verify_log << "Starting WEBrick on :4000\n"

        server = WEBrick::HTTPServer.new(
          Port: 4000,
          DocumentRoot: File.join(@dummy_root, "public"),
          AccessLog: [],
          Logger: WEBrick::Log.new(File::NULL)
        )

        Thread.new { server.start }
        sleep 0.4 # Give server time to boot

        check("/panda-core-assets") # ensure folder exists
        check("/panda-core-assets/application.js")
        check("/panda-core-assets/application.css")

        check("/assets/importmap.json")

      rescue => e
        @summary.verify_log << "ERROR verifying assets: #{e.message}\n"
        @summary.mark_verify_failed!
      ensure
        server&.shutdown
      end

      private

      def check(path)
        url = URI("http://localhost:4000#{path}")
        res = Net::HTTP.get_response(url)

        if res.is_a?(Net::HTTPSuccess)
          @summary.verify_log << "OK: #{path}\n"
        else
          @summary.verify_log << "MISSING: #{path}\n"
          @summary.mark_verify_failed!
        end
      rescue => e
        @summary.verify_log << "ERROR fetching #{path}: #{e.message}\n"
        @summary.mark_verify_failed!
      end
    end
  end
end
