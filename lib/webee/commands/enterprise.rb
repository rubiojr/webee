module WeBee
  module Commands
    class Enterprise < Command
      require 'mixlib/cli'
      include Mixlib::CLI
        option :help,
          :short => "-h",
          :long => "--help",
          :description => "Show this message",
          :on => :tail,
          :boolean => true,
          :show_options => true,
          :exit => 0

        option :name,
          :long => '--name NAME'
        
      def run
        actions = %w{create}
        if not actions.include? ARGV.first
          $stderr.puts "Invalid action.\n\nAVAILABLE ACTIONS: #{actions.join(' ')}\n\n"
          return 
        else
          if config[:name].nil?
            $stderr.puts 'Invalid Enterprise name.'
            $stderr.puts opt_parser.help
            return
          end

          begin
            ::WeBee::Enterprise.create :name => config[:name]
          rescue Exception => e
            puts e.message
          end

        end
      end

    end
  end
end
