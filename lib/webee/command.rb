module WeBee
  class Command

    def self.list_all
      cmds = []
      Dir[File.dirname(__FILE__) + '/commands/*.rb'].each do |cmd|
        cmds << File.basename(cmd, '.rb')
      end
      cmds
    end

    def initialize(args)
      @argv = args
    end
    
    def help
    end

    def self.print_help(cmd)
      require "#{File.dirname(__FILE__)}/commands/#{cmd}.rb"
      klass = WeBee::Commands.const_get cmd.capitalize
      obj = klass.new(ARGV)
      obj.help
    end
  
    def self.execute(cmd)
      require "#{File.dirname(__FILE__)}/commands/#{cmd}.rb"
      klass = WeBee::Commands.const_get cmd.capitalize
      obj = klass.new(ARGV)
      obj.parse_options
      obj.run
    end

  end
end
