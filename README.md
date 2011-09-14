# Installation

gem install webee


# Usage

    $: << '../lib'
    require 'webee'
    require 'md5'
    
    WeBee::Api.user = ENV['user'] || 'admin'
    WeBee::Api.password = ENV['pass'] || 'xabiquo'
    WeBee::Api.url = 'http://abiquo/api'
    
    #
    # List all datacenters available
    # 
    WeBee::Datacenter.all.each do |dc|
      puts dc.name
    end
    
    
    # 
    # Return the first datacenter whose name matches BCN (matched via Regexp)
    #
    dc = WeBee::Datacenter.find_by_name('BCN').first
    puts dc.name
    
    #
    # List Datacenter Racks
    #
    dc.racks.each do |r|
      puts r.name
    end
    
    #
    # List all the enterprises
    #
    WeBee::Enterprise.all.each do |e|
      puts e.name
    end
    
    #
    # Find an enterprise named QA
    #
    qa_ent = WeBee::Enterprise.find_by_name('QA')
    
    #
    # List enterprise 'QA' users
    #
    qa_ent.users.each do |u|
      puts u.name
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
    user.delete
    
    #
    # Create a new datacenter
    # FIXME: not implemented in WeBee
    #
    # WeBee::Datacenter.create :name => 'Test DC'
    
    #
    # List WeBee::OVFPackage available in enterprise QA
    #
    qa_ent.ovf_packages.each do |pkg|
      puts "#{pkg.product_name} (#{pkg.category_name})"
    end
    
    #
    # Create a new Rack
    #
    dc = WeBee::Datacenter.find_by_name('BCN').first
    rack = WeBee::Rack.create dc.datacenter_id,
                              :name => 'rack_1',
                              :ha_enabled => false,
                              :vlan_min_id => 100,
                              :vlan_max_id => 2048,
                              :vlan_per_vdc_expected => 6,
                              :nrsq => 80
    
    #
    # Delete the rack
    # FIXME: Not supported in Abiquo right now
    #
    #rack.delete


More examples can be found in the examples folder

