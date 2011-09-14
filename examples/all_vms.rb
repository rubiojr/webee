$: << '../lib'
require 'webee'
require 'md5'
require 'active_support'
require 'term/ansicolor'

class String
  include Term::ANSIColor
end

WeBee::Api.user = ENV['user'] || 'admin'
WeBee::Api.password = ENV['pass'] || 'xabiquo'
WeBee::Api.url = 'http://server/api'

include WeBee

Datacenter.all.each do |dc|
  dc.racks.each do |rack|
    puts "Rack: #{rack.name}"
    rack.machines.each do |machine|
      puts "Machine:".green.bold + " #{machine.name} (#{machine.virtual_machines.size} VMs)"
      machine.virtual_machines.each do |vm|
        if vm.managed?
          puts "  Name:".yellow.bold + " #{vm.name} " + "Enterprise:".yellow.bold + " #{vm.enterprise.name} " + "VDC:".yellow.bold + " #{vm.vdc.name}"
        else
          puts "  Name:".yellow.bold + " #{vm.name} "
        end
      end
    end
  end
end
