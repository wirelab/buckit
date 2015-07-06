require "buckit/cli/base_cmd"

module Buckit
  module CLI

    class List < BaseCmd
      def initialize
        super 'list', false, false, false

        @short_desc = "List all available buckets"
      end

      def run s3, bucket, args
        s3.list_buckets.buckets.each { |b| puts b.name }
      end
    end
  end
end
