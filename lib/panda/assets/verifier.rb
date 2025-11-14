# frozen_string_literal: true

require "json"
require "webrick"
require "benchmark"

module Panda
  module Assets
    class Verifier
      include UI

      def initialize(summary)
        @summary = summary
      end

      def run!
        UI.banner("Verify Panda Assets")

        t = Benchmark.realtime do
          check_basic_files
          parse_json
          http_checks
        end

        @summary.record_time(:verify_total, t)
      end

      private

      def dummy_root
        ENV["dummy_root"] || "spec/dummy"
      end

      def assets_dir
        File.join(dummy_root, "public/assets")
      end

      def check_basic_files
        ok = Dir.exist?(assets_dir)
        @summary.record_verify(:assets_dir, ok)
        ok ? UI.ok("Assets dir OK") : UI.error("Missing assets dir")
      end

      def parse_json
        manifest_ok = importmap_ok = false

        begin
          JSON.parse(File.read(File.join(assets_dir, ".manifest.json")))
          manifest_ok = true
        rescue
        end

        begin
          JSON.parse(File.read(File.join(assets_dir, "importmap.json")))
          importmap_ok = true
        rescue
        end

        @summary.record_verify(:manifest_parse, manifest_ok)
        @summary.record_verify(:importmap_parse, importmap_ok)
      end

      #
      # Fire up a mini WEBrick and check important assets
      #
      def http_checks
        UI.step("Starting WEBrick")

        server = WEBrick::HTTPServer.new(
          Port: 4579,
          DocumentRoot: File.join(dummy_root, "public"),
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: []
        )

        thread = Thread.new { server.start }
        sleep 0.3

        check_js("panda/core/application.js")
        check_fingerprinted

        server.shutdown
        thread.kill
      end

      def fetch(path)
        uri = URI("http://127.0.0.1:4579#{path}")
        res = Net::HTTP.get_response(uri)
        res.is_a?(Net::HTTPSuccess)
      rescue
        false
      end

      def check_js(name)
        ok = fetch("/assets/#{name}")
        @summary.record_verify("js:#{name}".to_sym, ok)
        ok ? UI.ok("JS OK: #{name}") : UI.error("JS missing: #{name}")
      end

      def check_fingerprinted
        manifest_path = File.join(assets_dir, ".manifest.json")
        manifest = JSON.parse(File.read(manifest_path))

        manifest.keys.each do |digest|
          ok = fetch("/assets/#{digest}")
          key = "fp:#{digest}".to_sym
          @summary.record_verify(key, ok)
          ok ? UI.ok("OK fp #{digest}") : UI.error("Missing fp: #{digest}")
        end
      end
    end
  end
end
