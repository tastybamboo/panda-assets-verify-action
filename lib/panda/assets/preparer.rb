# frozen_string_literal: true

require "fileutils"

module Panda
  module Assets
    class Preparer
      include Ui

      def initialize(dummy_root:, summary:)
        @dummy_root = File.expand_path(dummy_root)
        @summary = summary
      end

      def run!
        Ui.banner("Prepare Panda Assets")

        # Capture all output
        log_io = StringIO.new
        $stdout = Tee.new($stdout, log_io)

        begin
          compile_propshaft
          copy_engine_js
          generate_importmap
        rescue => e
          Ui.error("Preparation failed: #{e.message}")
          @summary.mark_prepare_failed!
        ensure
          $stdout = $stdout.original
          @summary.prepare_log = log_io.string
        end
      end

      private

      def compile_propshaft
        Ui.step("Compiling Propshaft assets")
        system("bin/rails assets:precompile") or raise "Propshaft failed"
        Ui.ok("Compiled propshaft assets")
      end

      def copy_engine_js
        Ui.step("Copying engine JS")
        src = File.join(Dir.pwd, "app/javascript/panda")
        dest = File.join(@dummy_root, "app/javascript/panda")
        FileUtils.mkdir_p(dest)
        FileUtils.cp_r("#{src}/.", dest)
        Ui.ok("Copied JS")
      end

      def generate_importmap
        Ui.step("Generating importmap.json")
        system("bin/rails importmap:json") or raise "Failed importmap generation"
        Ui.ok("Generated importmap")
      end

      #
      # Used to clone stdout and capture logs
      #
      class Tee
        attr_reader :original

        def initialize(original, clone)
          @original = original
          @clone = clone
        end

        def write(*args)
          @original.write(*args)
          @clone.write(*args)
        end

        def flush
          @original.flush
          @clone.flush
        end
      end
    end
  end
end
