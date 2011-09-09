require 'rubygems'
$: << '../lib'
require 'webee'
require 'md5'
require 'alchemist'
require 'colorize'
require 'terminal-table/import'

include WeBee
Alchemist::use_si = true

WeBee::Api.user = ENV['user'] || 'admin'
WeBee::Api.password = ENV['pass'] || 'xabiquo'
WeBee::Api.url = "http://#{ENV['host']}/api"

stats = {
  :free_hd => 0, 
  :real_hd => 0,
  :used_hd => 0, 
  :hypervisors => 0,
  :free_ram => 0,
  :real_ram => 0,
  :used_ram => 0,
  :available_cpus => 0
}

Datacenter.all.each do |dc|
  dc.racks.each do |rack|
    puts "#" * 80
    puts "Rack: #{rack.name} Datacenter: #{dc.name}"
    rack.machines.each do |m|
      puts "#" * 80
      stats[:hypervisors] += 1
      stats[:used_ram] += m.ram_used.to_i
      stats[:real_ram] += m.real_ram.to_i
      stats[:available_cpus] += m.real_cpu.to_i
      stats[:used_hd] += m.hd_used.to_i.bytes.to.gigabytes.to_f.round
      stats[:real_hd] += m.real_hd.to_i.bytes.to.gigabytes.to_f.round
      ds_table = table do |t|
        t.headings = "Datastores"
        m.datastores.each do |ds|
          t << ["Name:       ".light_yellow,"#{ds.name}"]
          t << ["Enabled:    ".light_yellow,"#{ds.enabled}"]
          t << ["Size:       ".light_yellow,"#{ds.size.to_i.bytes.to.gigabytes.to_i} GB"]
          t << ["Used Size:  ".light_yellow,"#{ds.used_size.to_i.bytes.to.gigabytes.to_i} GB"]
        end
      end
      user_table = table do 
        self.headings = "  #{m.name.upcase.light_green}"
        add_row ["IP:".light_yellow, "#{m.ip}"]
        add_row ["CPUs:".light_yellow, "#{m.real_cpu}"]
        add_row ["State:".light_yellow, "#{m.state}"]
        add_row ["Hypervisor Type:".light_yellow,"#{m.hypervisortype}"]
        add_row ["RAM:".light_yellow,"#{m.real_ram.to_i} MB"]
        add_row ["RAM Used:".light_yellow,"#{m.ram_used.to_i} MB"]
        add_row ["RAM Free:".light_yellow,"#{m.real_ram.to_i - m.ram_used.to_i} MB"]
        add_row ["HD Size:".light_yellow,"#{m.real_hd.to_i.bytes.to.gigabytes.to_i} GB"]
        add_row ["HD Used:".light_yellow,"#{m.hd_used.to_i.bytes.to.gigabytes.to_i} GB"]
        add_row ["HD Free:".light_yellow,"#{(m.real_hd.to_i - m.hd_used.to_i).bytes.to.gigabytes.to_i} GB"]
        add_row ["CPU Used:".light_yellow,"#{m.cpu_used.to_i}"]
      end
      puts user_table
      puts ds_table
      puts "#" * 80
      puts "\n\n"
    end
  end
end

stats[:free_ram] = stats[:real_ram] - stats[:used_ram]
stats[:free_hd] = stats[:real_hd] - stats[:used_hd]

puts "\n"
puts "#" * 80
puts "Cloud Stats"
puts "#" * 80
user_table = table do
  self.headings = ['Cloud Statistics']
  add_row ["Hypevisors:".light_yellow, "#{stats[:hypervisors]}"]
  add_row ["Available CPUs:".light_yellow, "#{stats[:available_cpus]}"]
  add_row ["Total RAM:".light_yellow,"#{stats[:real_ram].megabytes.to.gigabytes} GB"]
  add_row ["Free RAM:".light_yellow,"#{stats[:free_ram].megabytes.to.gigabytes} GB"]
  add_row ["Used RAM:".light_yellow,"#{stats[:used_ram].megabytes.to.gigabytes} GB"]
  add_row ["Total HD:".light_yellow, "#{stats[:real_hd]} GB"]
  add_row ["Free HD:".light_yellow, "#{stats[:free_hd]} GB"]
  add_row ["Used HD:".light_yellow, "#{stats[:used_hd]} GB"]
end
puts user_table
puts "#" * 80
