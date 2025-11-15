# frozen_string_literal: true

module Panda
  module Assets
    module ErrorHelper
      module_function

      # Common error patterns and their solutions
      SOLUTIONS = {
        /command not found.*bundle/ => [
          "Bundle is not installed or not in PATH",
          "Try: gem install bundler",
          "Or ensure Ruby/Bundler are properly installed"
        ],
        /Could not find.*in any of the sources/ => [
          "Missing dependencies in Gemfile",
          "Try: bundle install",
          "Or check if all gems are properly specified"
        ],
        /Rails is not currently installed/ => [
          "Rails gem is missing",
          "Try: bundle install",
          "Ensure rails is in your Gemfile"
        ],
        /Cannot find module|Module not found/ => [
          "JavaScript module not found",
          "Check importmap.rb configuration",
          "Ensure all JavaScript files are in the correct location"
        ],
        /ENOENT.*No such file or directory/ => [
          "File or directory not found",
          "Check that all required files exist",
          "Verify paths are correct"
        ],
        /Permission denied/ => [
          "Insufficient permissions",
          "Check file/directory permissions",
          "You may need to run with appropriate permissions"
        ],
        /Address already in use/ => [
          "Port is already in use by another process",
          "Try setting PANDA_ASSETS_PORT to a different port",
          "Or stop the process using the port"
        ],
        /LoadError.*cannot load such file/ => [
          "Ruby file or gem cannot be loaded",
          "Check that all required gems are installed",
          "Run: bundle install"
        ],
        /SyntaxError/ => [
          "Syntax error in Ruby or JavaScript code",
          "Check recent changes for syntax issues",
          "Look for missing brackets, quotes, or semicolons"
        ],
        /ActiveRecord::.*Migration/ => [
          "Database migration issue",
          "Try: rails db:migrate RAILS_ENV=test",
          "Or: rails db:schema:load RAILS_ENV=test"
        ]
      }.freeze

      # Format an error with context and possible solutions
      def format_error(error, context = {})
        lines = []

        # Error header
        lines << "━" * 60
        lines << "❌ ERROR: #{context[:operation] || 'Operation failed'}"
        lines << "━" * 60

        # Error details
        if context[:file]
          lines << "📁 File: #{context[:file]}"
        end

        if context[:command]
          lines << "💻 Command: #{context[:command]}"
        end

        if context[:path]
          lines << "📍 Path: #{context[:path]}"
        end

        lines << ""
        lines << "🔴 Error Message:"
        lines << "   #{error}"

        # Find matching solutions
        solutions = find_solutions(error)
        if solutions.any?
          lines << ""
          lines << "💡 Possible Solutions:"
          solutions.each { |solution| lines << "   • #{solution}" }
        end

        # Additional context
        if context[:hint]
          lines << ""
          lines << "ℹ️  Hint: #{context[:hint]}"
        end

        lines << "━" * 60
        lines.join("\n")
      end

      # Find solutions based on error message
      def find_solutions(error_message)
        solutions = []

        SOLUTIONS.each do |pattern, suggestions|
          if error_message.match?(pattern)
            solutions.concat(suggestions)
          end
        end

        solutions.uniq
      end

      # Format a warning message
      def format_warning(message, context = {})
        lines = []
        lines << "⚠️  Warning: #{message}"

        if context[:suggestion]
          lines << "   💡 #{context[:suggestion]}"
        end

        lines.join("\n")
      end

      # Create a detailed error summary for the final report
      def error_summary(errors, phase)
        return nil if errors.empty?

        lines = []
        lines << "#{phase} Phase Errors (#{errors.size}):"
        lines << "─" * 40

        errors.each_with_index do |error, index|
          lines << "  #{index + 1}. #{error}"

          solutions = find_solutions(error)
          if solutions.any?
            lines << "     💡 Try: #{solutions.first}"
          end
          lines << ""
        end

        lines.join("\n")
      end
    end
  end
end