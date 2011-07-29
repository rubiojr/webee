module WeBee
  module Commands
    class User < Command
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

        option :surname,
          :long => '--surname SURNAME'

        option :email,
          :long => '--email EMAIL'
        
        option :description,
          :long => '--description DESC',
          :default => ''
        
        option :nick,
          :long => '--nick NICK'
        
        option :active,
          :long => '--active VAL',
          :default => 1

        option :enterprise,
          :long => '--enterprise ENT',
          :default => 1

        option :locale,
          :long => '--locale LOCALE',
          :default => 'en_US'

        option :password,
          :long => '--password PASS'

        option :role,
          :long => '--role ROLE',
          :default => 'cloud-admin'

      def run
        roles_map = { 
                      'cloud-admin' => WeBee::UserRole.cloud_admin,
                      'enterprise-admin' => WeBee::UserRole.enterprise_admin,
                      'user' => WeBee::UserRole.user
                    }

        actions = %w{create}
        if not actions.include? ARGV.first
          $stderr.puts "Invalid action.\n\nAVAILABLE ACTIONS: #{actions.join(' ')}\n\n"
          return 
        else
          if config[:name].nil?
            $stderr.puts 'Invalid user name.'
            $stderr.puts opt_parser.help
            return
          end
          if config[:surname].nil?
            $stderr.puts 'Invalid surname.'
            $stderr.puts opt_parser.help
            return
          end
          if config[:email].nil?
            $stderr.puts 'Invalid email.'
            $stderr.puts opt_parser.help
            return
          end
          if config[:nick].nil?
            $stderr.puts 'Invalid nick.'
            $stderr.puts opt_parser.help
            return
          end
          if config[:password].nil?
            $stderr.puts 'Invalid password.'
            $stderr.puts opt_parser.help
            return
          end
          role = roles_map[config[:role]]
          if role.nil?
            $stderr.puts "Invalid role.\n\nAVAILABLE_ROLES: cloud-admin enterprise-admin user\n\n"
            $stderr.puts opt_parser.help
            return
          end


          begin
          ::WeBee::User.create :name => config[:name],
                                     :surname => config[:surname],
                                     :email => config[:email],
                                     :description => config[:description],
                                     :nick => config[:nick],
                                     :password => config[:password],
                                     :role => role,
                                     :locale => config[:locale],
                                     :enterprise => Enterprise.find(config[:enterprise]),
                                     :active => config[:active]
          rescue Exception => e
            puts e.message
          end
        end
      end

    end
  end
end
