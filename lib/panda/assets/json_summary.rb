# frozen_string_literal: true

require "json"
require "fileutils"

module Panda
  module Assets
    class JSONSummary
      def self.write!(summary, path)
        FileUtils.mkdir_p(File.dirname(path))
        data = {
          prepare: {
            ok: summary.prepare_ok?,
            log: summary.prepare_log
          },
          verify: {
            ok: summary.verify_ok?,
            log: summary.verify_log
          },
          result: summary.failed? ? "FAIL" : "PASS"
        }
        File.write(path, JSON.pretty_generate(data))
      end
    end
  end
end
