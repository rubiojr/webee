$: << '../lib'
require 'rubygems'
require 'webee'
require 'md5'

CIAB_IP = ENV['host'] || '127.0.0.1'

WeBee::Api.user = ENV['user'] || 'admin'
WeBee::Api.password = ENV['pass'] || 'xabiquo'
WeBee::Api.url = "http://#{ENV['host'] || 'abiquo'}/api"

#
# Add a license
#
license_file = ARGV[0]
if license_file.nil? or (not File.exist?(license_file))
  $stderr.puts "Invalid license file"
  exit 1
end
WeBee::Config.add_license File.read(license_file).strip.chomp

dc = WeBee::Datacenter.create :name => 'BCN'
ent = WeBee::Enterprise.all.first
ent.set_limits_for_datacenter dc

rack = dc.add_rack :name => 'rack_1',
                   :ha_enabled => false,
                   :vlan_min_id => 100,
                   :vlan_max_id => 2048,
                   :vlan_per_vdc_expected => 6,
                   :nrsq => 80

machine = dc.discover_machine :ip => CIAB_IP, :hypervisortype => 'kvm'
machine.virtual_switch = machine.virtual_switches.first
machine.datastores.first.enabled = true 
rack.add_machine(machine)
vdc = ent.create_vdc :name => 'kvm-vdc', :hypervisortype => 'KVM', :datacenter => dc
