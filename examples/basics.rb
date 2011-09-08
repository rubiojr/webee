$: << '../lib'
require 'webee'
require 'md5'

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

#
# Create a new datacenter
#
# This assumes the Remote Services are located in the same server
#
dc = WeBee::Datacenter.create :name => 'BCN'

#
# Advanced Datacenter Creation: 
#
# If you want to add a Datacenter with remote services located in another host
# use this.
#
# remote_services= WeBee::RemoteService.create_for_host("10.60.1.24")
# WeBee::Datacenter.create :name => 'foo'
#                         :remote_services => remote_services


#
# List all datacenters available
# 
WeBee::Datacenter.all.each do |dc|
  # do something like printing dc.name
end

# 
# Return the first datacenter whose name matches BCN (matched via Regexp)
#
dc = WeBee::Datacenter.find_by_name('BCN').first
# puts dc.name

#
# Create an enterprise
#
ent = WeBee::Enterprise.create :name => 'QA'

#
# List all the enterprises
#
WeBee::Enterprise.all.each do |e|
  # do something like printing e.name
end

#
# Find an enterprise named QA
#
qa_ent = WeBee::Enterprise.find_by_name('QA').first

#
# List enterprise 'QA' users
#
qa_ent.users.each do |u|
  # print user name
  # puts u.name
end


#
# Create a new user in QA enterprise
# 
user = qa_ent.create_user :name => 'Sergio Rubio',
                   :role => WeBee::UserRole.cloud_admin,
                   :password => MD5.hexdigest('rubiojr'),
                   :surname => 'rubiojr', #optional
                   :email => 'rubiojr@apient.com',
                   :locale => 'en_US',
                   :nick => 'rubiojr',
                   :active => 'true'  #optional

# delete the user
# user.delete

#
# List WeBee::OVFPackage available in enterprise QA
#
qa_ent.ovf_packages.each do |pkg|
  # print package info
  # puts "#{pkg.product_name} (#{pkg.category_name})"
end

#
# List Datacenter Racks
#
dc.racks.each do |r|
  # print rack name
  # puts r.name
end

#
# Create a new Rack
#
rack = dc.add_rack :name => 'rack_1',
                   :ha_enabled => false,
                   :vlan_min_id => 100,
                   :vlan_max_id => 2048,
                   :vlan_per_vdc_expected => 6,
                   :nrsq => 80

#
# Hypervisor (Machine) stuff
#
machine = dc.discover_machine :ip => '10.60.1.24', :hypervisortype => 'kvm'
# Use the first virtual switch we find
machine.virtual_switch = machine.virtual_switches.first
# Enable the first datastore found
machine.datastores.first.enabled = true 
# Add the hypervisor to the rack
rack.add_machine(machine)
# Delete the rack
# FIXME: Not supported in Abiquo right now
#rack.delete

#
# Create a Virtual Datacenter with default limits and network
#
qa = WeBee::Enterprise.find_by_name('QA').first
# We need to set limits for the enterprise to be able to use a datacenter
qa.set_limits_for_datacenter dc
#vdc = qa.create_vdc :name => 'kvm-vdc', :hypervisortype => 'KVM', :datacenter => dc

#
# Advanced VDC Creation
#
vdc = qa.create_vdc :datacenter => dc,
                    :name => 'kvm-vdc',
                    :hypervisortype => 'KVM', 
                    :ramSoft => 19456,
                    :ramHard => 20480,
                    :cpuSoft => 18,
                    :cpuHard => 20,
                    :storageSoft => 28991029248,
                    :storageHard => 32212254720,
                    :publicIpsSoft => 2,
                    :publicIpsHard => 4,
                    :hdSoft => 27917287424,
                    :hdHard => 32212254720,
                    :vlanSoft => 5,
                    :vlanHard => 10

# Find VDC by name
vdc = WeBee::VDC.find_by_name 'kvm-vdc'

#
# List all VDCs for my Enterprise
WeBee::VDC.all 

#
# List all VDCs from a specific Enterprise/Datacenter
# Needs Cloud operator privileges
# 
WeBee::VDC.all :datacenter_id => WeBee::Datacenter.all.first.datacenter_id, :enterprise_id => 3
