# frozen_string_literal: true

require "json"
require_relative "error_helper"

module Panda
  module Assets
    class Summary
      include ErrorHelper

      attr_reader :prepare, :verify, :timings,
                  :version_matrix, :importmap_tree,
                  :diff_missing, :module_summaries

      def initialize
        @prepare = { ok: false, log: [], errors: [] }
        @verify  = { ok: false, log: [], errors: [] }

        @timings         = {}
        @version_matrix  = []
        @importmap_tree  = nil
        @diff_missing    = []
        @module_summaries = []
      end

      # --- logging helpers ---

      def add_prepare_log(msg)
        # Ensure UTF-8 encoding and remove any binary characters
        safe_msg = msg.to_s.force_encoding('UTF-8')
        safe_msg = safe_msg.valid_encoding? ? safe_msg : safe_msg.encode('UTF-8', invalid: :replace, undef: :replace)
        @prepare[:log] << safe_msg
      end

      def add_verify_log(msg)
        # Ensure UTF-8 encoding and remove any binary characters
        safe_msg = msg.to_s.force_encoding('UTF-8')
        safe_msg = safe_msg.valid_encoding? ? safe_msg : safe_msg.encode('UTF-8', invalid: :replace, undef: :replace)
        @verify[:log] << safe_msg
      end

      def add_prepare_error(msg)
        @prepare[:errors] << msg
      end

      def add_verify_error(msg)
        @verify[:errors] << msg
      end

      # --- status helpers ---

      def mark_prepare_ok!
        @prepare[:ok] = true
      end

      def mark_verify_ok!
        @verify[:ok] = true
      end

      def mark_prepare_failed!
        @prepare[:ok] = false
      end

      def mark_verify_failed!
        @verify[:ok] = false
      end

      def prepare_ok?
        !!@prepare[:ok]
      end

      def verify_ok?
        !!@verify[:ok]
      end

      def prepare_errors
        @prepare[:errors]
      end

      def verify_errors
        @verify[:errors]
      end

      def failed?
        !prepare_ok? || !verify_ok?
      end

      # --- JSON / stdout ---

      def to_h
        {
          prepare: @prepare,
          verify: @verify,
          timings: @timings,
          version_matrix: @version_matrix,
          importmap_tree: @importmap_tree,
          diff_missing: @diff_missing,
          module_summaries: @module_summaries
        }
      end

      def to_json(*_args)
        JSON.pretty_generate(to_h)
      end

      def write_json!(path)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
        File.write(path, to_json)
      end

      def to_stdout!
        puts
        puts "────────────────────────────────────────"
        puts " Panda Assets Verification Summary"
        puts "────────────────────────────────────────"
        puts " Prepare: #{prepare_ok? ? 'OK' : 'FAILED'}"
        puts " Verify:  #{verify_ok? ? 'OK' : 'FAILED'}"

        if prepare_errors.any?
          puts
          puts error_summary(prepare_errors, "Prepare")
        end

        if verify_errors.any?
          puts
          puts error_summary(verify_errors, "Verify")
        end

        puts
        puts " Timings:"
        @timings.each do |k, v|
          puts "   - #{k}: #{format('%.2fs', v)}"
        end

        puts "────────────────────────────────────────"
        puts failed? ? " FINAL RESULT: FAIL" : " FINAL RESULT: PASS"
        puts "────────────────────────────────────────"
      end
    end
  end
end
