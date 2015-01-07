require 'buckit/exceptions'
require 'aws-sdk'
require 'cmdparse'
require "active_support/core_ext"
require "buckit/cli/base_cmd"

module Buckit
  module CLI

    class Delete < BaseCmd
      attr_accessor :force

      def initialize
        super 'delete', false, false

        @short_desc = "Remove a bucket"

        @force = false

        self.options = CmdParse::OptionParserWrapper.new do |opt|
          opt.on("-f", "--force", "Clean the bucket then deletes it") {|f|
            @force = f
          }
          opt.on("-r", "--region REGION", "specify a region, default eu-west-1. This must match the region in which the bucket resides.") {|region|
            @region = region
          }
          opt.on("-u", "--user", "USE WITH CARE! Removes the user with the name of the bucket, removes the policy named 'buckit' of this user, removes the users access_keys") {|user|
            @remove_user = user
          }
          opt.on("-s", "--skip", "Skip trying to delete the buckit. Handy if you just want to remove the user") {|skip|
            @skip = skip
          }

        end
      end

      def run s3, bucket, args
        raise WrongUsage.new(nil, "You need to specify a bucket") if not bucket

        # Getting the bucket
        bucket_obj = Aws::S3::Resource.new(region: region).bucket(bucket)

        begin
          # Do not kill buckets with content unless explicitly asked
          if not @force and bucket_obj.objects.count > 0
            raise FailureFeedback.new("Bucket `#{bucket}' still has files. Try with -f if you want to forcefully delete the bucket.")
          end
          unless @skip
            bucket_obj.delete!
            puts "bucket: #{bucket} has been deleted"
          end
          if @remove_user
            iam = Aws::IAM::Resource.new region: region
            user = iam.user(bucket)
            user.policy("buckit").delete
            puts "Policy deleted"
            user.access_keys.each(&:delete)
            puts "Access keys deleted"
            user.delete
            puts "User deleted"
          end

        rescue Aws::S3::Errors::PermanentRedirect => message
          raise FailureFeedback.new(message)
        end
      end
    end
  end
end
