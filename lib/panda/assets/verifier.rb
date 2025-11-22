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
          summary.add_verify_error("public/assets missing at #{assets_dir}")
          summary.add_verify_log("Assets directory not found: #{assets_dir}")
          summary.add_verify_log("Hint: Run 'rails assets:precompile' to generate assets")
          summary.mark_verify_failed!
          return
        end

        unless File.exist?(manifest_path)
          summary.add_verify_error(".manifest.json missing")
          summary.add_verify_log(".manifest.json missing at #{manifest_path}")
          summary.add_verify_log("This file should be created by 'rails assets:precompile'")
          summary.mark_verify_failed!
        end

        unless File.exist?(importmap_path)
          summary.add_verify_error("importmap.json missing")
          summary.add_verify_log("importmap.json missing at #{importmap_path}")
          summary.add_verify_log("Check that importmap-rails is configured correctly")
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
        summary.add_verify_error("JSON parse error: #{e.message}")
        summary.add_verify_log("Invalid JSON: #{e.message}")
        summary.add_verify_log("Check that manifest and importmap files contain valid JSON")
        summary.mark_verify_failed!
      end

      def http_checks
        return unless Dir.exist?(assets_dir)

        server, port = start_server

        begin
          verify_panda_javascript(port)
          verify_importmap(port)
          verify_manifest(port)
          verify_panda_asset_directories(port)
        ensure
          server&.shutdown
        end

        summary.mark_verify_ok! if summary.verify_errors.empty?
      rescue => e
        summary.add_verify_error("HTTP verification failed: #{e.class}: #{e.message}")
        summary.add_verify_log("#{e.class}: #{e.message}")
        summary.add_verify_log("Check that the server can start and assets are properly compiled")
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

        server_thread = Thread.new do
          begin
            server.start
          rescue => e
            summary.add_verify_error("Server thread crashed: #{e.class}: #{e.message}")
            raise e
          end
        end

        # Give thread a moment to crash if it's going to
        sleep 0.1
        unless server_thread.alive?
          raise "WEBrick server thread died immediately - check for port conflicts"
        end

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

        # In CI, give more time for server startup (15s vs 5s)
        max_attempts = ENV["CI"] == "true" ? 150 : 50

        max_attempts.times do |attempt|
          begin
            res = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
            if res.is_a?(Net::HTTPResponse)
              spinner.stop(success: true, final_message: "Server started successfully")
              return
            end
          rescue StandardError
            # Log progress in CI for debugging
            if ENV["CI"] == "true" && attempt > 0 && attempt % 50 == 0
              summary.add_verify_log("Still waiting for server... (#{attempt * 0.1}s elapsed)")
            end
            # keep retrying
          end
          sleep 0.1
        end

        spinner.stop(success: false, final_message: "Server failed to start")
        raise "WEBrick did not start listening on port #{port} in time (waited #{max_attempts * 0.1}s)"
      end

      def http_get(path, port)
        uri = URI("http://127.0.0.1:#{port}#{path}")
        res = Net::HTTP.get_response(uri)
        res
      rescue => e
        summary.add_verify_error("HTTP error for #{path}: #{e.class}: #{e.message}")
        nil
      end

      def verify_panda_javascript(port)
        # Check for panda JavaScript files that are critical for the test environment
        # These are served from public/panda/ directory in the test environment

        summary.add_verify_log("\n🔍 Panda JavaScript Module Verification:")
        summary.add_verify_log("=" * 60)

        panda_js_root = File.join(dummy_root, "public", "panda")

        unless Dir.exist?(panda_js_root)
          summary.add_verify_log("⚠️  No panda JavaScript directory found at #{panda_js_root}")
          summary.add_verify_log("   This may cause JavaScript loading issues in tests")
          return
        end

        # Find all JavaScript files in the panda directory
        js_files = Dir.glob(File.join(panda_js_root, "**/*.js"))

        if js_files.empty?
          summary.add_verify_log("⚠️  No JavaScript files found in #{panda_js_root}")
          return
        end

        summary.add_verify_log("Found #{js_files.size} JavaScript files to verify")

        success_count = 0
        failure_count = 0

        js_files.each do |file_path|
          # Convert file path to URL path
          relative_path = file_path.sub(File.join(dummy_root, "public"), "")
          http_path = relative_path

          res = http_get(http_path, port)

          if res && res.is_a?(Net::HTTPSuccess)
            success_count += 1
            summary.add_verify_log("✅ #{relative_path}")
            summary.add_verify_log("   Status: HTTP #{res.code} OK")
            summary.add_verify_log("   Size: #{res['Content-Length']} bytes") if res['Content-Length']
          else
            failure_count += 1
            status = res ? "HTTP #{res.code}" : "CONNECTION FAILED"
            summary.add_verify_log("❌ #{relative_path}")
            summary.add_verify_log("   Status: #{status}")

            # Don't add to verify_errors since these might be optional
            # but log them for debugging
            if relative_path.include?("application.js")
              # application.js is critical - this should be an error
              summary.add_verify_error("Critical file missing: #{relative_path} (#{status})")
            end
          end
        end

        summary.add_verify_log("=" * 60)
        summary.add_verify_log("Panda JS Summary: #{success_count} passed, #{failure_count} failed")

        # Also check if files are accessible from app/javascript/panda path
        # This is where ModuleRegistry middleware expects them
        app_js_root = File.join(dummy_root, "app", "javascript", "panda")
        if Dir.exist?(app_js_root)
          app_js_files = Dir.glob(File.join(app_js_root, "**/*.js"))
          summary.add_verify_log("\n📂 app/javascript/panda: #{app_js_files.size} files present")
          if app_js_files.any?
            # Show first few files as confirmation
            app_js_files.first(3).each do |f|
              relative = f.sub(dummy_root, "")
              summary.add_verify_log("   - #{relative}")
            end
            summary.add_verify_log("   ...") if app_js_files.size > 3
          end
        else
          summary.add_verify_log("\n⚠️  No app/javascript/panda directory found")
          summary.add_verify_log("   ModuleRegistry middleware expects files here for runtime")
        end

        summary.add_verify_log("")
      end

      def verify_panda_asset_directories(port)
        asset_dirs = Dir.glob(File.join(dummy_root, "public", "panda-*-assets"))
        return if asset_dirs.empty?

        summary.add_verify_log("\n🧵 Panda Asset Directory Verification")
        summary.add_verify_log("=" * 60)

        total_files = 0
        failures = 0

        asset_dirs.each do |dir|
          Dir.glob(File.join(dir, "**/*")).each do |file|
            next unless File.file?(file)

            total_files += 1
            relative_path = file.sub(File.join(dummy_root, "public"), "")
            res = http_get(relative_path, port)

            if res && res.is_a?(Net::HTTPSuccess)
              length = res["Content-Length"] || File.size(file)
              summary.add_verify_log("✅ #{relative_path} (#{length} bytes)")
            else
              failures += 1
              status = res ? "HTTP #{res.code}" : "CONNECTION FAILED"
              summary.add_verify_log("❌ #{relative_path} (#{status})")
              summary.add_verify_error("Panda asset inaccessible: #{relative_path} (#{status})")
            end
          end
        end

        summary.add_verify_log("=" * 60)
        summary.add_verify_log("Asset verification summary: #{total_files - failures} passed, #{failures} failed")
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

        summary.add_verify_log("\n📋 Importmap Asset Verification Report:")
        summary.add_verify_log("=" * 60)

        current = 0
        total = local_imports.size
        success_count = 0
        failure_count = 0

        local_imports.each do |name, path|
          current += 1
          UI.progress(current, total, "Checking importmap entries")

          http_path = path.start_with?("/") ? path : "/assets/#{path}"

          res = http_get(http_path, port)

          if res && res.is_a?(Net::HTTPSuccess)
            success_count += 1
            summary.add_verify_log("✅ #{name}")
            summary.add_verify_log("   URL: #{http_path}")
            summary.add_verify_log("   Status: HTTP #{res.code} OK")
          else
            failure_count += 1
            error_detail = if res
              case res.code
              when "404"
                "File not found - may not have been compiled or copied correctly"
              when "403"
                "Permission denied - check file permissions"
              when "500"
                "Server error - check server logs for details"
              else
                "HTTP #{res.code} - unexpected response"
              end
            else
              "No response - connection failed"
            end

            summary.add_verify_log("❌ #{name}")
            summary.add_verify_log("   URL: #{http_path}")
            summary.add_verify_log("   Status: #{res ? "HTTP #{res.code}" : "CONNECTION FAILED"}")
            summary.add_verify_log("   Error: #{error_detail}")

            msg = "Import '#{name}' failed: #{error_detail}\n     Path: #{http_path}"
            summary.add_verify_error(msg)
            summary.diff_missing << http_path
          end
        end

        summary.add_verify_log("=" * 60)
        summary.add_verify_log("Importmap Summary: #{success_count} passed, #{failure_count} failed")
        summary.add_verify_log("")
      rescue JSON::ParserError => e
        summary.add_verify_error("JSON parse error for importmap.json: #{e.message}")
      end

      def verify_manifest(port)
        return unless File.exist?(manifest_path)

        manifest = JSON.parse(File.read(manifest_path))

        summary.add_verify_log("Verifying #{manifest.size} manifest entries via HTTP")
        summary.add_verify_log("\n📦 Manifest Asset Verification Report:")
        summary.add_verify_log("=" * 60)

        current = 0
        total = manifest.size
        success_count = 0
        failure_count = 0

        manifest.each do |logical_path, asset_info|
          current += 1
          UI.progress(current, total, "Checking manifest assets")

          # Propshaft manifest maps logical paths to asset info hashes
          # Extract the digested_path from the hash
          digested_filename = if asset_info.is_a?(Hash)
            asset_info["digested_path"] || asset_info[:digested_path]
          else
            asset_info # Fallback for simple string format
          end

          unless digested_filename
            failure_count += 1
            summary.add_verify_log("❌ #{logical_path}")
            summary.add_verify_log("   Error: Missing digested_path in manifest")
            summary.add_verify_error("Missing digested_path for #{logical_path}")
            next
          end

          # We need to check the actual digested file
          http_path = "/assets/#{digested_filename}"
          res = http_get(http_path, port)

          if res && res.is_a?(Net::HTTPSuccess)
            success_count += 1
            summary.add_verify_log("✅ #{logical_path}")
            summary.add_verify_log("   URL: #{http_path}")
            summary.add_verify_log("   Status: HTTP #{res.code} OK")
            summary.add_verify_log("   Digested: #{digested_filename}")
          else
            failure_count += 1
            error_detail = if res
              case res.code
              when "404"
                "Asset not found - check compilation output"
              when "403"
                "Permission denied - check file permissions"
              when "500"
                "Server error - check server configuration"
              else
                "HTTP #{res.code}"
              end
            else
              "No response - connection failed"
            end

            # Provide more context for common asset types
            file_hint = case File.extname(logical_path)
            when ".js"
              "JavaScript file may have compilation errors"
            when ".css"
              "CSS file may have syntax errors or missing dependencies"
            when ".map"
              "Source map file - can be ignored if not using source maps"
            else
              "Check that this file was generated during compilation"
            end

            summary.add_verify_log("❌ #{logical_path}")
            summary.add_verify_log("   URL: #{http_path}")
            summary.add_verify_log("   Status: #{res ? "HTTP #{res.code}" : "CONNECTION FAILED"}")
            summary.add_verify_log("   Digested: #{digested_filename}")
            summary.add_verify_log("   Error: #{error_detail}")
            summary.add_verify_log("   Hint: #{file_hint}")

            msg = "Manifest asset failed: #{error_detail}\n     Logical path: #{logical_path}\n     Digested file: #{digested_filename}\n     Hint: #{file_hint}"
            summary.add_verify_error(msg)
            summary.diff_missing << logical_path
          end
        end

        summary.add_verify_log("=" * 60)
        summary.add_verify_log("Manifest Summary: #{success_count} passed, #{failure_count} failed")
        summary.add_verify_log("")
      rescue JSON::ParserError => e
        summary.add_verify_error("JSON parse error for .manifest.json: #{e.message}")
      end
    end
  end
end
