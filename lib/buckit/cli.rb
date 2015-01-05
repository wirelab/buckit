require 'buckit/version'
require 'buckit/exceptions'
require 'aws/s3'
require 'cmdparse'

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
        # Connecting to amazon
        s3 = AWS::S3.new

        # From the command line
        key, file = args

        # Parsing the bucket name
        bucket = nil
        bucket, key = key.split(':') if key

        # Running our custom method inside of the command class, taking care
        # of the common errors here, saving duplications in each command;
        begin
          run s3, bucket, key, file, args
        rescue AWS::S3::Errors::AccessDenied
          raise FailureFeedback.new("Access Denied")
        rescue AWS::S3::Errors::NoSuchBucket
          raise FailureFeedback.new("There's no bucket named `#{bucket}'")
        rescue AWS::S3::Errors::NoSuchKey
          raise FailureFeedback.new("There's no key named `#{key}' in the bucket `#{bucket}'")
        rescue AWS::S3::Errors::Base => exc
          raise FailureFeedback.new("Error: `#{exc.message}'")
        end
      end
    end

    class List < BaseCmd
      def initialize
        super 'list', false, false, false

        @short_desc = "List all available buckets"
      end

      def run s3, bucket, key, file, args
        bucket_names = []
        s3.buckets.each do |bkt|
          bucket_names << "#{bkt.name}"
        end
        bucket_names.each { |bkt| puts bkt }
      end
    end

    class Create < BaseCmd
      attr_accessor :region

      def initialize
        super 'create', false, false

        @short_desc = "Create a new bucket"
        @region = 'eu-west-1'

        self.options = CmdParse::OptionParserWrapper.new do |opt|
          opt.on("-r", "--region", "specify a region, default eu-west-1") {|f|
            @region = r
          }
        end
      end

      def run s3, bucket, key, file, args
        raise WrongUsage.new(nil, "You need to supply a bucket name") if not bucket

        # Create bucket
        AWS.config(region: @region)
        begin
          s3.buckets.create(bucket, acl: :public_read)
        rescue AWS::S3::Errors::BucketAlreadyExists
          raise FailureFeedback.new("Bucket `#{bucket}' already exists")
        end

        # Create IAM
        begin
          user = AWS.iam.users.create(name)
          access_key = user.access_keys.create
          credentials = access_key.credentials
        rescue AWS::Errors::ClientError
          #TODO Rollback
          raise FailureFeedback.new("Failed creating IAM")
        end

        # Create Policy
        begin
          policy = AWS::IAM::Policy.new
          policy.allow(
            actions: ["s3:AbortMultipartUpload",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
            "s3:GetBucketLogging",
            "s3:GetBucketNotification",
            "s3:GetBucketVersioning",
            "s3:GetBucketWebsite",
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:GetObjectTorrent",
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl",
            "s3:GetObjectVersionTorrent",
            "s3:ListBucket",
            "s3:ListBucketVersions",
            "s3:PutBucketAcl",
            "s3:PutBucketLogging",
            "s3:PutBucketNotification",
            "s3:PutBucketVersioning",
            "s3:PutBucketWebsite",
            "s3:PutLifecycleConfiguration",
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:PutObjectVersionAcl"],
            resources: ["arn:aws:s3:::#{bucket}", "arn:aws:s3:::#{bucket}/*"]
          )
          policy_options = {}
          policy_options[:user_name] = user.name
          policy_options[:policy_name] = "buckit"
          policy_options[:policy_document] = policy.to_json
          AWS.iam.client.put_user_policy policy_options
        rescue AWS::Errors::ClientError
          #TODO Rollback
          raise FailureFeedback.new("Failed creating policy")
        end

        puts "#{bucket}: AWS_ACCESS_KEY_ID=#{credentials[:access_key_id]} AWS_SECRET_ACCESS_KEY=#{credentials[:secret_access_key]}"
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
        end
      end

      def run s3, bucket, key, file, args
        raise WrongUsage.new(nil, "You need to specify a bucket") if not bucket

        # Getting the bucket
        bucket_obj = s3.buckets[bucket]

        # Do not kill buckets with content unless explicitly asked
        if not @force and bucket_obj.objects.count > 0
          raise FailureFeedback.new("Bucket `#{bucket}' still has files. Try with -f if you want to forcefully delete the bucket.")
        end

        bucket_obj.delete!
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
