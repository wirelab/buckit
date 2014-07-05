require 'netrc'
require 'fileutils'

module Buckit
  module Auth
    attr_reader :credentials
    def auth_access_key
      get_credentials[0]
    end

    def auth_access_secret
      get_credentials[1]
    end

    def get_credentials
      @credentials ||= (read_credentials || ask_for_and_save_credentials)
    end

    def read_credentials
      netrc['nl.wirelab.buckit']
    end

    def netrc_path
      default = Netrc.default_path
      encrypted = default + ".gpg"
      if File.exists?(encrypted)
        encrypted
      else
        default
      end
    end

    def ask_for_credentials
      logger.info 'Enter your AWS key'
      key = gets.chomp
      logger.info 'Enter your AWS secret'
      secret = gets.chomp

      [key, secret]
    end

    def ask_for_and_save_credentials
      begin
        @credentials = ask_for_credentials
        write_credentials
      end
      @credentials
    end

    def write_credentials
      FileUtils.mkdir_p(File.dirname(netrc_path))
      FileUtils.touch(netrc_path)
      netrc['nl.wirelab.buckit'] = self.credentials
      netrc.save
    end

    def netrc
      @netrc ||= begin
        File.exists?(netrc_path) && Netrc.read(netrc_path)
      rescue => error
        if error.message =~ /^Permission bits for/
          perm = File.stat(netrc_path).mode & 0777
          abort("Permissions #{perm} for '#{netrc_path}' are too open. You should run `chmod 0600 #{netrc_path}` so that your credentials are NOT accessible by others.")
        else
          raise error
        end
      end
    end
  end
end
