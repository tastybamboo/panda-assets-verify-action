# frozen_string_literal: true

module Panda
  module Assets
    class Summary
      attr_reader :prepare_checks, :verify_checks, :timings

      def initialize
        @prepare_checks = {}
        @verify_checks = {}
        @timings = {}
      end

      def record_prepare(key, ok)
        @prepare_checks[key] = ok
      end

      def record_verify(key, ok)
        @verify_checks[key] = ok
      end

      def record_time(key, seconds)
        @timings[key] = seconds
      end

      def failed?
        (@prepare_checks.values + @verify_checks.values).any? { |v| v == false }
      end
    end
  end
end
