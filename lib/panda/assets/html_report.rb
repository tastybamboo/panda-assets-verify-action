# frozen_string_literal: true

require "erb"
require "fileutils"

module Panda
  module Assets
    class HTMLReport
      TEMPLATE = File.expand_path("../templates/report.html.erb", __FILE__)

      def self.write!(summary, out_path)
        FileUtils.mkdir_p(File.dirname(out_path))

        html = ERB.new(File.read(TEMPLATE)).result(summary.instance_eval { binding })
        File.write(out_path, html)
      end
    end
  end
end
