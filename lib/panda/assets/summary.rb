# frozen_string_literal: true

require "json"
require "fileutils"

module Panda
  module Assets
    class Summary
      attr_accessor :prepare, :verify

      def initialize
        @prepare = { ok: true, errors: [], log: +"", timings: {} }
        @verify  = { ok: true, errors: [], log: +"", timings: {} }
      end

      def add_prepare_error(msg)
        @prepare[:ok] = false
        @prepare[:errors] << msg
      end

      def add_verify_error(msg)
        @verify[:ok] = false
        @verify[:errors] << msg
      end

      def failed?
        !prepare[:ok] || !verify[:ok]
      end

      def to_json
        {
          prepare: prepare,
          verify: verify,
          result: failed? ? "FAIL" : "PASS"
        }.to_json
      end

      def write_json!(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, to_json)
      end
    end
  end
end
