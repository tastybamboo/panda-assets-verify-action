# frozen_string_literal: true

require "webrick"
require "json"

module Panda
  module Assets
    class Verifier
      include Ui

      def initialize(dummy_root:, summary:)
        @dummy_root = File.expand_path(dummy_root)
        @summary = summary
      end

      def run!
        Ui.banner("Verify Panda Assets")

        log_io = StringIO.new
        $stdout = Tee.new($stdout, log_io)

        begin
          verify_basic
          start_server_and_run_checks
        rescue => e
          Ui.error("Verification failed: #{e.message}")
          @summary.mark_verify_failed!
        ensure
          $stdout = $stdout.original
          @summary.verify_log = log_io.string
        end
      end

      private

      def verify_basic
        assets_dir = File.join(@dummy_root, "public/assets")
        Ui.ok("Assets dir OK") if Dir.exist?(assets_dir)
      end

      def start_server_and_run_checks
        Ui.step("Starting WEBrick")

        root = File.join(@dummy_root, "public")
        server = WEBrick::HTTPServer.new(
          Port: 4579,
          DocumentRoot: root,
          AccessLog: [],
          Logger: WEBrick::Log.new("/dev/null")
        )

        Thread.new { server.start }
        sleep 0.3

        begin
          check_js
          check_manifest_files
        ensure
          server.shutdown
        end
      end

      def check_js
        required = ["panda/core/application.js"]

        required.each do |path|
          check_http("/#{path}", "JS missing: #{path}")
        end
      end

      def check_manifest_files
        manifest = File.join(@dummy_root, "public/assets/.manifest.json")
        return unless File.exist?(manifest)

        required = JSON.parse(File.read(manifest)).keys

        required.each do |file|
          check_http("/assets/#{file}", "Missing fp: #{file}")
        end
      end

      def check_http(path, error_message)
        res = Net::HTTP.get_response(URI("http://127.0.0.1:4579#{path}"))
        if res.code != "200"
          Ui.error(error_message)
          @summary.mark_verify_failed!
        end
      end

      class Tee
        attr_reader :original

        def initialize(original, clone)
          @original = original
          @clone = clone
        end

        def write(*args)
          @original.write(*args)
          @clone.write(*args)
        end

        def flush
          @original.flush
          @clone.flush
        end
      end
    end
  end
end
