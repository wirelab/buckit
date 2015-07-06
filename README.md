# Buckit

Buckit provides a list of commands that will allow you to manage your content
stored in S3 buckets. To learn about each feature, please use the `help`
command:

Heavily inspired from https://github.com/clarete/s3sync

Confgure you

## Installation

Add this line to your application's Gemfile:

    gem 'buckit'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install buckit

Configure your environment

* `ENV['AWS_ACCESS_KEY_ID']` and `ENV['AWS_SECRET_ACCESS_KEY']`
* The shared credentials ini file at `~/.aws/credentials` ([more information](http://blogs.aws.amazon.com/security/post/Tx3D6U6WSFGOK2H/A-New-and-Standardized-Way-to-Manage-Credentials-in-the-AWS-SDKs))

## Usage

    buckit create NAME -r REGION -a CANNED_ACL

This will:
- create a new s3 bucket in eu-west-1 region
- set a canned ACL (default public-read)
- create a IAM User that has full access to the bucket, with as user_name NAME
- set a default CORS

The output format is easy to copy paste to heroku and works in conjunction with the asset_sync gem.

Options:
```
    -r, --region REGION              specify a region, default eu-west-1
    -a, --acl ACL_POLICY             specify a canned acl, default public-read. Allowed acl's are: private, public-read, public-read-write, authenticated-read. See http://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html
```

    buckit delete NAME -r REGION

This will delete a buckit. Optional parameters:
```
    -f, --force                      Clean the bucket then deletes it
    -r, --region REGION              specify a region, default eu-west-1. This must match the region in which the bucket resides.
    -u, --user                       USE WITH CARE! Removes the user with the name of the bucket, removes the policy named 'buckit' of this user, removes the users access_keys
    -s, --skip                       Skip trying to delete the buckit. Handy if you just want to remove the user
```

    buckit list

List all buckets

For more options check buckit --help

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
