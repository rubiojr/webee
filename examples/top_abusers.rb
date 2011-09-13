$: << '../lib'
require 'webee'
require 'md5'
require 'active_support'

WeBee::Api.user = ENV['user'] || 'admin'
WeBee::Api.password = ENV['pass'] || 'xabiquo'
WeBee::Api.url = 'http://server/api'

include WeBee

abusers = {}

Enterprise.all.each do |ent|
  ent.users.each do |user|
    abusers[user.name] = { :full_name => "#{user.name} #{user.surname}", :email => user.email, :vms => user.virtual_machines.size }
  end
end

abusers = abusers.sort do |a,b|
  puts a[1][:vms]
  a[1][:vms] <=> b[1][:vms]
end.reverse

abusers.each do |a|
  puts "User: #{a[1][:full_name]}".ljust(40) + "VMs: #{a[1][:vms]}"
end
