# frozen_string_literal: true

module Panda
  module Assets
    class Summary
      attr_accessor :prepare_log, :verify_log
      attr_reader :timings

      def initialize
        @prepare_log = +""
        @verify_log  = +""
        @prepare_failed = false
        @verify_failed  = false
        @timings = {}
      end

      def add_error(type, msg)
        case type
        when /prepare/
          @prepare_log << "ERROR: #{msg}\n"
          @prepare_failed = true
        when /verify/
          @verify_log << "ERROR: #{msg}\n"
          @verify_failed = true
        end
      end

      def mark_prepare_failed!
        @prepare_failed = true
      end

      def mark_verify_failed!
        @verify_failed = true
      end

      def prepare_ok?
        !@prepare_failed
      end

      def verify_ok?
        !@verify_failed
      end

      def failed?
        @prepare_failed || @verify_failed
      end

      #
      # Console summary for CI logs
      #
      def to_stdout!
        puts "\n────────────────────────────────────────"
        puts " Panda Assets Verification Summary"
        puts "────────────────────────────────────────"

        puts " Prepare: #{prepare_ok? ? "OK" : "FAILED"}"
        puts " Verify:  #{verify_ok? ? "OK" : "FAILED"}"

        puts "\n--- Prepare log ---\n#{@prepare_log}" unless @prepare_log.empty?
        puts "\n--- Verify log ---\n#{@verify_log}" unless @verify_log.empty?

        puts "────────────────────────────────────────"
        puts failed? ? " FINAL RESULT: FAIL" : " FINAL RESULT: PASS"
        puts "────────────────────────────────────────"
      end
    end
  end
end
