require 'buckit/version'
require 'cmdparse'

require "buckit/cli/base_cmd"
require "buckit/cli/delete"
require "buckit/cli/list"
require "buckit/cli/create"

module Buckit
  module CLI
    def run
      cmd = CmdParse::CommandParser.new true
      cmd.program_name = File.basename $0
      cmd.program_version = Buckit::VERSION

      cmd.options = CmdParse::OptionParserWrapper.new do |opt|
        opt.separator "Global options:"
      end

      cmd.main_command.short_desc = 'Toolbelt for managing your S3 buckets'
      cmd.main_command.description =<<END.strip
Buckit provides a list of commands that will allow you to manage your S3 buckets. To learn about each feature, please use the `help`
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
