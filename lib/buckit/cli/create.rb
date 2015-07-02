require "buckit/cli/base_cmd"

module Buckit
  module CLI

    class Create < BaseCmd
      attr_accessor :region

      def initialize
        super 'create', false, false

        @short_desc = "Create a new bucket"

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
        add_policy_to_user(bucket)
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
          credentials.access_key
        rescue Aws::IAM::Errors::ServiceError
          raise FailureFeedback.new("Failed creating IAM")
        end
      end

      def add_policy_to_user bucket
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
  end
end
