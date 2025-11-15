# frozen_string_literal: true

require "erb"
require "fileutils"

module Panda
  module Assets
    class HTMLReport
      TEMPLATE_PATH = File.expand_path("templates/report.html.erb", __dir__)

      def self.write!(summary, path)
        new(summary, path).write!
      end

      def initialize(summary, path)
        @summary = summary
        @path    = path
      end

      def write!
        dir = File.dirname(@path)
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

        html = render
        File.write(@path, html)
      end

      private

      attr_reader :summary

      def render
        template = File.read(TEMPLATE_PATH)
        ERB.new(template).result(binding)
      end
    end
  end
end
