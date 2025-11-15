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

      def reset
        colour("0")
      end

      def green(str)
        "#{colour("32")}#{str}#{reset}"
      end

      def red(str)
        "#{colour("31")}#{str}#{reset}"
      end

      def yellow(str)
        "#{colour("33")}#{str}#{reset}"
      end

      def cyan(str)
        "#{colour("36")}#{str}#{reset}"
      end

      def bold(str)
        "#{colour("1")}#{str}#{reset}"
      end

      # Strip ANSI escape sequences from a string to get visible length
      def strip_ansi(str)
        str.gsub(/\e\[[0-9;]*m/, '')
      end

      # Now accepts optional status: :ok / :fail / nil
      def banner(title, status: nil)
        label =
          case status
          when :ok  then "[#{green('OK')}] "
          when :fail then "[#{red('FAIL')}] "
          else ""
          end

        heading = "#{label}#{title}"
        # Calculate visible length without ANSI codes for proper alignment
        visible_length = strip_ansi(heading).size
        line_len = [visible_length + 4, 24].max
        line = "─" * line_len

        puts
        puts cyan("┌#{line}┐")
        puts cyan("│ ") + bold(heading) + cyan(" │")
        puts cyan("└#{line}┘")
      end

      def step(title)
        puts "• #{title}"
      end

      def ok(msg)
        puts "   #{green('✓')} #{msg}"
      end

      def warn(msg)
        puts "   #{yellow('!')} #{msg}"
      end

      def error(msg)
        puts "   #{red('✗')} #{msg}"
      end

      def divider
        puts cyan("-" * 60)
      end

      # Show progress for operations with multiple items
      def progress(current, total, message = "Processing")
        percentage = (current.to_f / total * 100).round
        bar_width = 30
        filled = (bar_width * current / total).round
        empty = bar_width - filled

        bar = "█" * filled + "░" * empty

        # Use \r to overwrite the same line
        print "\r   #{message}: [#{cyan(bar)}] #{current}/#{total} (#{percentage}%)"

        # Print newline when complete
        puts if current >= total
      end

      # Spinner for long-running operations
      class Spinner
        FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏]

        def initialize(message)
          @message = message
          @running = false
          @thread = nil
          @frame_index = 0
        end

        def start
          @running = true
          @thread = Thread.new do
            while @running
              print "\r   #{UI.cyan(FRAMES[@frame_index])} #{@message}"
              @frame_index = (@frame_index + 1) % FRAMES.length
              sleep 0.1
            end
          end
        end

        def stop(success: true, final_message: nil)
          @running = false
          @thread&.join

          if final_message
            status = success ? UI.green("✓") : UI.red("✗")
            print "\r   #{status} #{final_message}"
          else
            print "\r" + " " * (@message.length + 5) + "\r"  # Clear the line
          end
          puts
        end
      end

      # Convenience method to run a block with a spinner
      def with_spinner(message)
        spinner = Spinner.new(message)
        spinner.start

        begin
          result = yield
          spinner.stop(success: true, final_message: "#{message} - done")
          result
        rescue => e
          spinner.stop(success: false, final_message: "#{message} - failed")
          raise e
        end
      end
    end
  end
end
