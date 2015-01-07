require 'buckit/exceptions'
require 'aws-sdk'
require 'cmdparse'
require "active_support/core_ext"

module Buckit
  module CLI
    class BaseCmd < CmdParse::Command
      @has_prefix = false

      def has_options?
        not options.instance_variables.empty?
      end

      def has_prefix?
        @has_prefix
      end

      def region
        @region || 'eu-west-1'
      end

      def usage
        u = []
        u << "Usage: #{File.basename commandparser.program_name} #{name} "
        u << "[options] " if has_options?
        u << "'bucket name'" if has_args?

        if has_prefix? == 'required'
          u << ':prefix'
        elsif has_prefix?
          u << "[:prefix]"
        end

        u.join ''
      end

      def execute(args)
        # Set default region, required
        Aws.config[:region] = region

        # Connecting to amazon
        s3 = Aws::S3::Client.new

        # From the command line
        bucket, = args

        # Running our custom method inside of the command class, taking care
        # of the common errors here, saving duplications in each command;
        begin
          run s3, bucket, args
        rescue Aws::S3::Errors::AccessDenied
          raise FailureFeedback.new("Access Denied")
        rescue Aws::S3::Errors::NoSuchBucket
          raise FailureFeedback.new("There's no bucket named `#{bucket}'")
        rescue Aws::S3::Errors::BucketAlreadyOwnedByYou => message
          raise FailureFeedback.new(message)
        rescue Aws::S3::Errors => message
          raise FailureFeedback.new("Error: `#{message}'")
        end
      end
    end
  end
end
