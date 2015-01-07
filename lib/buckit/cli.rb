require 'buckit/version'
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

    class List < BaseCmd
      def initialize
        super 'list', false, false, false

        @short_desc = "List all available buckets"
      end

      def run s3, bucket, args
        s3.list_buckets.buckets.each { |b| puts b.name }
      end
    end

    class Create < BaseCmd
      attr_accessor :region

      def initialize
        super 'create', false, false

        @short_desc = "Create a new bucket"
        @region = 'eu-west-1'

        self.options = CmdParse::OptionParserWrapper.new do |opt|
          opt.on("-r", "--region REGION", "specify a region, default eu-west-1") {|region|
            @region = region
          }
        end
      end

      def run s3, bucket, args
        raise WrongUsage.new(nil, "You need to supply a bucket name") if not bucket

        # Create bucket
        create_bucket(s3, bucket)
        credentials = create_user(bucket)
        create_policy(bucket)
        add_cors(s3, bucket)

        puts "FOG_DIRECTORY=#{bucket} FOG_PROVIDER=AWS FOG_REGION=#{@region} ASSET_HOST=#{Aws::S3::Resource.new.bucket(bucket).url} AWS_ACCESS_KEY_ID=#{credentials.access_key_id} AWS_SECRET_ACCESS_KEY=#{credentials.secret_access_key}"
      end

      protected
      def create_bucket s3, bucket
        s3.create_bucket(
          acl: "public-read",
          bucket: bucket
        )
      end

      def create_user bucket
        begin
          iam = Aws::IAM::Client.new
          iam.create_user(user_name: bucket, path: '/apps/')
          credentials = iam.create_access_key(user_name: bucket)
          credentials.first.access_key
        rescue Aws::IAM::Errors::ServiceError
          raise FailureFeedback.new("Failed creating IAM")
        end
      end

      def create_policy bucket
        begin
          iam = Aws::IAM::Client.new
          policy = {
            "Statement" => [
              {
                "Action" => ["s3:AbortMultipartUpload", "s3:DeleteObject", "s3:DeleteObjectVersion", "s3:GetBucketAcl", "s3:GetBucketLocation", "s3:GetBucketLogging", "s3:GetBucketNotification", "s3:GetBucketVersioning", "s3:GetBucketWebsite", "s3:GetObject", "s3:GetObjectAcl", "s3:GetObjectTorrent", "s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTorrent", "s3:ListBucket", "s3:ListBucketVersions", "s3:PutBucketAcl", "s3:PutBucketLogging", "s3:PutBucketNotification", "s3:PutBucketVersioning", "s3:PutBucketWebsite", "s3:PutLifecycleConfiguration", "s3:PutObject", "s3:PutObjectAcl", "s3:PutObjectVersionAcl"],
                "Effect" => "Allow",
                "Resource" => ["arn:aws:s3:::#{bucket}", "arn:aws:s3:::#{bucket}/*"]
              }
            ]
          }
          iam.put_user_policy(user_name: bucket, policy_name: 'buckit', policy_document: policy.to_json)
        rescue Aws::IAM::Errors::ServiceError
          raise FailureFeedback.new("Failed creating policy")
        end
      end

      def add_cors s3, bucket
        begin
          s3.put_bucket_cors(
            bucket: bucket,
            cors_configuration: {
              cors_rules: [
                {
                  allowed_headers: ['*'],
                  allowed_methods: ["GET", "POST", "PUT"],
                  allowed_origins: ['*'],
                  expose_headers: [],
                  max_age_seconds: 3000
                },
              ]
            }
          )
        rescue Aws::S3::Errors::ServiceError
          raise FailureFeedback.new("Failed creating CORS")
        end
      end
    end

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


          bucket_obj.delete!
          puts "#{bucket} has been deleted"
        rescue Aws::S3::Errors::PermanentRedirect => message
          raise FailureFeedback.new(message)
        end
      end
    end

    def run
      cmd = CmdParse::CommandParser.new true
      cmd.program_name = File.basename $0
      cmd.program_version = Buckit::VERSION

      cmd.options = CmdParse::OptionParserWrapper.new do |opt|
        opt.separator "Global options:"
      end

      cmd.main_command.short_desc = 'Tool belt for managing your S3 buckets'
      cmd.main_command.description =<<END.strip
Buckit provides a list of commands that will allow you to manage your content
stored in S3 buckets. To learn about each feature, please use the `help`
command:
  $ #{File.basename $0} help create"
END

      # Bucket related options
      cmd.add_command List.new
      cmd.add_command Create.new
      cmd.add_command Delete.new

      # Built-in commands
      cmd.add_command CmdParse::HelpCommand.new
      cmd.add_command CmdParse::VersionCommand.new

      # Boom! Execute it
      cmd.parse
    end

    module_function :run
  end
end
