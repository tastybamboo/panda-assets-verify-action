# frozen_string_literal: true

module Panda
  module Assets
    class Summary
      attr_accessor :prepare_log, :verify_log

      def initialize
        @prepare_log = +""
        @verify_log  = +""
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
    end
  end
end
