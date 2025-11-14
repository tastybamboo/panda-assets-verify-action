# frozen_string_literal: true

module Panda
  module Assets
    module UI
      module_function

      def colour_enabled?
        $stdout.tty? && ENV["NO_COLOR"].nil?
      end

      def colour(code)
        return "" unless colour_enabled?
        "\e[#{code}m"
      end

      def reset  = colour("0")
      def green(s) = "#{colour("32")}#{s}#{reset}"
      def red(s)   = "#{colour("31")}#{s}#{reset}"
      def yellow(s)= "#{colour("33")}#{s}#{reset}"
      def cyan(s)  = "#{colour("36")}#{s}#{reset}"
      def bold(s)  = "#{colour("1")}#{s}#{reset}"

      def banner(title)
        line = "─" * (title.length + 10)
        puts
        puts cyan("┌#{line}┐")
        puts cyan("│ ") + bold(title) + cyan(" │")
        puts cyan("└#{line}┘")
      end

      def step(s)  = puts "• #{s}"
      def ok(s)    = puts "   #{green("✓")} #{s}"
      def warn(s)  = puts "   #{yellow("!")} #{s}"
      def error(s) = puts "   #{red("✗")} #{s}"
    end
  end
end
