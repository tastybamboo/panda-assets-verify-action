# frozen_string_literal: true

module Panda
  module Assets
    #
    # ErrorHelper
    #
    # A small, stable utility module for formatting and categorising errors
    # across the Preparer, Verifier, and Runner pipelines.
    #
    module ErrorHelper
      module_function

      # Formats an error message into a standard predictable form.
      #
      # Examples:
      #   format_error("prepare", "Missing manifest.json")
      #   # => "[PREPARE] Missing manifest.json"
      #
      #   format_exception("verify", err)
      #   # => "[VERIFY] RuntimeError: Something broke"
      #
      def format_error(category, message)
        "[#{category.to_s.upcase}] #{message}"
      end

      # Formats an exception into a single-line error.
      #
      # Usage:
      #   format_exception("prepare", e)
      #   => "[PREPARE] RuntimeError: invalid data"
      #
      def format_exception(category, exception)
        formatted = "#{exception.class}: #{exception.message}"
        format_error(category, formatted)
      end

      #
      # Helper to add an error to Summary consistently:
      #
      #   add_error(summary, :prepare, "Something failed")
      #
      def add_error(summary, category, message)
        case category
        when :prepare
          summary.add_prepare_error(format_error(category, message))
        when :verify
          summary.add_verify_error(format_error(category, message))
        when :http
          summary.add_verify_error(format_error(category, message))
        else
          summary.add_verify_error(format_error(category, message))
        end
      end

      #
      # Same but for exceptions:
      #
      def add_exception(summary, category, exception)
        add_error(summary, category, format_exception(category, exception))
      end
    end
  end
end