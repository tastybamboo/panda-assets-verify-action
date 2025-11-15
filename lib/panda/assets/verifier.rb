# frozen_string_literal: true

require "webrick"
require "net/http"
require "json"
require "benchmark"
require "socket"
require_relative "error_helper"

module Panda
  module Assets
    class Verifier
      include UI
      include ErrorHelper

      attr_reader :dummy_root, :summary

      def initialize(dummy_root:, summary:)
        @dummy_root = File.expand_path(dummy_root)
        @summary    = summary
      end

      def run
        check_basic_files
        load_json
        http_checks
      end

      private

      def assets_dir
        File.join(dummy_root, "public", "assets")
      end

      def manifest_path
        File.join(assets_dir, ".manifest.json")
      end

      def importmap_path
        File.join(assets_dir, "importmap.json")
      end

      def check_basic_files
        summary.add_verify_log("Checking basic asset files")

        unless Dir.exist?(assets_dir)
          error_msg = format_error(
            "Assets directory not found",
            operation: "Asset Directory Check",
            path: assets_dir,
            hint: "Run 'rails assets:precompile' to generate assets"
          )
          summary.add_verify_error("public/assets missing at #{assets_dir}")
          summary.add_verify_log(error_msg)
          summary.mark_verify_failed!
          return
        end

        unless File.exist?(manifest_path)
          warning = format_warning(
            ".manifest.json missing at #{manifest_path}",
            suggestion: "This file should be created by 'rails assets:precompile'"
          )
          summary.add_verify_error(".manifest.json missing")
          summary.add_verify_log(warning)
          summary.mark_verify_failed!
        end

        unless File.exist?(importmap_path)
          warning = format_warning(
            "importmap.json missing at #{importmap_path}",
            suggestion: "Check that importmap-rails is configured correctly"
          )
          summary.add_verify_error("importmap.json missing")
          summary.add_verify_log(warning)
          summary.mark_verify_failed!
        end
      end

      def load_json
        return unless File.exist?(manifest_path) && File.exist?(importmap_path)

        t = Benchmark.realtime do
          manifest = JSON.parse(File.read(manifest_path))
          importmap = JSON.parse(File.read(importmap_path))

          summary.importmap_tree = importmap
          summary.timings[:verify_manifest_parse] = 0.0 # compatibility
          summary.timings[:verify_importmap_parse] = 0.0
          summary.add_verify_log("Parsed manifest (#{manifest.size} entries)")
          summary.add_verify_log("Parsed importmap.json")
        end

        summary.timings[:verify_json_total] = t
      rescue JSON::ParserError => e
        error_msg = format_error(
          "Invalid JSON: #{e.message}",
          operation: "JSON File Parsing",
          hint: "Check that manifest and importmap files contain valid JSON"
        )
        summary.add_verify_error("JSON parse error: #{e.message}")
        summary.add_verify_log(error_msg)
        summary.mark_verify_failed!
      end

      def http_checks
        return unless Dir.exist?(assets_dir)

        server, port = start_server

        begin
          verify_importmap(port)
          verify_manifest(port)
        ensure
          server&.shutdown
        end

        summary.mark_verify_ok! if summary.verify_errors.empty?
      rescue => e
        error_msg = format_error(
          "#{e.class}: #{e.message}",
          operation: "HTTP Asset Verification",
          hint: "Check that the server can start and assets are properly compiled"
        )
        summary.add_verify_error("HTTP verification failed: #{e.class}: #{e.message}")
        summary.add_verify_log(error_msg)
        summary.mark_verify_failed!
      end

      def start_server
        root = File.join(dummy_root, "public")
        port = find_available_port

        server = WEBrick::HTTPServer.new(
          Port: port,
          DocumentRoot: root,
          BindAddress: '127.0.0.1',  # Explicitly bind to localhost only
          AccessLog: [],
          Logger: WEBrick::Log.new(File::NULL)
        )

        Thread.new { server.start }

        wait_for_server(port)

        summary.add_verify_log("Started WEBrick at http://127.0.0.1:#{port} serving #{root}")
        [server, port]
      end

      def find_available_port
        # Check for environment variable first
        if ENV["PANDA_ASSETS_PORT"]
          port = ENV["PANDA_ASSETS_PORT"].to_i
          if port > 0 && port < 65536
            summary.add_verify_log("Using port #{port} from PANDA_ASSETS_PORT environment variable")
            return port
          else
            summary.add_verify_log("Invalid PANDA_ASSETS_PORT value: #{ENV['PANDA_ASSETS_PORT']}, using default")
          end
        end

        # Try default port first, then try alternatives if needed
        default_port = 4579
        ports_to_try = [default_port, 4580, 4581, 4582, 0]  # 0 means let OS choose

        ports_to_try.each do |port|
          begin
            # Test if port is available by trying to bind to it
            test_server = TCPServer.new('127.0.0.1', port)
            actual_port = test_server.addr[1]  # Get actual port (important if port was 0)
            test_server.close

            if port == 0
              summary.add_verify_log("Using OS-assigned port #{actual_port}")
            elsif port != default_port
              summary.add_verify_log("Port #{default_port} was in use, using alternative port #{actual_port}")
            end

            return actual_port
          rescue Errno::EADDRINUSE, Errno::EACCES => e
            summary.add_verify_log("Port #{port} unavailable: #{e.message}")
            next
          end
        end

        raise "Could not find an available port for the test server"
      end

      def wait_for_server(port)
        spinner = UI::Spinner.new("Waiting for server to start on port #{port}")
        spinner.start

        50.times do
          begin
            res = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
            if res.is_a?(Net::HTTPResponse)
              spinner.stop(success: true, final_message: "Server started successfully")
              return
            end
          rescue StandardError
            # keep retrying
          end
          sleep 0.1
        end

        spinner.stop(success: false, final_message: "Server failed to start")
        raise "WEBrick did not start listening on port #{port} in time"
      end

      def http_get(path, port)
        uri = URI("http://127.0.0.1:#{port}#{path}")
        res = Net::HTTP.get_response(uri)
        res
      rescue => e
        summary.add_verify_error("HTTP error for #{path}: #{e.class}: #{e.message}")
        nil
      end

      def verify_importmap(port)
        return unless File.exist?(importmap_path)

        importmap = JSON.parse(File.read(importmap_path))
        imports = importmap["imports"] || {}

        if imports.empty?
          summary.add_verify_log("Importmap has no imports; skipping HTTP checks for imports")
          return
        end

        summary.add_verify_log("Verifying #{imports.size} importmap imports via HTTP")

        # Filter out external URLs first
        local_imports = imports.reject do |_name, path|
          path.start_with?("http://", "https://")
        end

        if local_imports.empty?
          summary.add_verify_log("All imports are external; skipping HTTP checks")
          return
        end

        current = 0
        total = local_imports.size

        local_imports.each do |name, path|
          current += 1
          UI.progress(current, total, "Checking importmap entries")

          http_path = path.start_with?("/") ? path : "/assets/#{path}"

          res = http_get(http_path, port)
          next unless res

          unless res.is_a?(Net::HTTPSuccess)
            error_detail = case res.code
            when "404"
              "File not found - may not have been compiled or copied correctly"
            when "403"
              "Permission denied - check file permissions"
            when "500"
              "Server error - check server logs for details"
            else
              "HTTP #{res.code} - unexpected response"
            end

            msg = "Import '#{name}' failed: #{error_detail}\n     Path: #{http_path}"
            summary.add_verify_error(msg)
            summary.diff_missing << http_path
          end
        end
      rescue JSON::ParserError => e
        summary.add_verify_error("JSON parse error for importmap.json: #{e.message}")
      end

      def verify_manifest(port)
        return unless File.exist?(manifest_path)

        manifest = JSON.parse(File.read(manifest_path))

        summary.add_verify_log("Verifying #{manifest.size} manifest entries via HTTP")

        current = 0
        total = manifest.size

        manifest.keys.each do |file|
          current += 1
          UI.progress(current, total, "Checking manifest assets")

          # Propshaft manifest keys are digest filenames relative to /assets
          http_path = "/assets/#{file}"
          res = http_get(http_path, port)
          next unless res

          unless res.is_a?(Net::HTTPSuccess)
            error_detail = case res.code
            when "404"
              "Asset not found - check compilation output"
            when "403"
              "Permission denied - check file permissions"
            when "500"
              "Server error - check server configuration"
            else
              "HTTP #{res.code}"
            end

            # Provide more context for common asset types
            file_hint = case File.extname(file)
            when ".js"
              "JavaScript file may have compilation errors"
            when ".css"
              "CSS file may have syntax errors or missing dependencies"
            when ".map"
              "Source map file - can be ignored if not using source maps"
            else
              "Check that this file was generated during compilation"
            end

            msg = "Manifest asset failed: #{error_detail}\n     File: #{file}\n     Hint: #{file_hint}"
            summary.add_verify_error(msg)
            summary.diff_missing << file
          end
        end
      rescue JSON::ParserError => e
        summary.add_verify_error("JSON parse error for .manifest.json: #{e.message}")
      end
    end
  end
end
