# frozen_string_literal: true

module Panda
  module Assets
    class Summary
      attr_accessor :prepare_log, :verify_log

      def initialize
        @prepare_log   = +""
        @verify_log    = +""
        @prepare_failed = false
        @verify_failed  = false
      end

      def mark_prepare_failed!
        @prepare_failed = true
      end

      def mark_verify_failed!
        @verify_failed = true
      end

      def failed?
        @prepare_failed || @verify_failed
      end

      #
      # Print a clean summary to STDOUT (GitHub Actions log friendly)
      #
      def to_stdout!
        puts
        puts "────────────────────────────────────────"
        puts " Panda Assets Verification Summary"
        puts "────────────────────────────────────────"

        puts " Prepare: #{@prepare_failed ? "FAILED" : "OK"}"
        puts " Verify:  #{@verify_failed ? "FAILED" : "OK"}"
        puts

        if @prepare_failed
          puts " Prepare log:"
          puts indent(@prepare_log)
          puts
        end

        if @verify_failed
          puts " Verify log:"
          puts indent(@verify_log)
          puts
        end

        puts "────────────────────────────────────────"
        puts failed? ? " FINAL RESULT: FAIL" : " FINAL RESULT: PASS"
        puts "────────────────────────────────────────"
      end

      private

      def indent(text)
        text.split("\n").map { |l| "   #{l}" }.join("\n")
      end
    end
  end
end
