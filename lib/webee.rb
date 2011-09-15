require 'rubygems'
require 'rest_client'
require 'sax-machine'
require 'nokogiri'
require 'active_support/core_ext/hash'
require 'uri'
require 'json'
require 'builder'
require 'alchemist'

#
# Monkeypatch SAXMachine to keep the raw XMK
#
# Ugly but fun, isn't it? This may blow up at some point
#
module SAXMachine

  alias_method :old_parse, :parse

  def parse(xml, on_error = nil, on_warning = nil)
    obj = old_parse(xml, on_error, on_warning)
    obj.instance_variable_set :@raw, xml
    obj.class.send :define_method, 'raw' do
      @raw
    end
    obj
  end
end

module WeBee 

  VERSION = '0.3.4'

  module RestResource
    
    module ClassMethods

      def find(id)
        self.parse(RestClient.get(Api.url + "#{@resource_path}/#{id}"))
      end
    
      def all(options = {})
        col = []
        doc = Nokogiri.parse(RestClient.get(Api.url + "#{@resource_path}"))
        pages = doc.search('//totalSize').text.to_i / 25
        pages = 1 if pages == 0
        1.upto(pages) do |p|
          doc.search("//#{@resource_name}").each do |node|
            col << self.parse(node.to_s)
          end
        end
        col
      end

      def resource_path(path)
        @resource_path = path
      end
      
      def resource_name(name)
        @resource_name = name
      end

    end
      
    def self.included(base)
      base.extend(ClassMethods)
    end

  end

  class Config
      def self.add_license(hash)
        RestClient.post Api.url + "/config/licenses" , "<license><code>#{hash}</code></license>", :content_type => :xml
      end
  end


  class Api
    class << self
      attr_accessor :user, :password, :url, :port, :host

      def url=(url)
        @url = build_url(url)
      end

      def build_url(url)
        port ||= 80
        uri = URI.parse(url)
        @host = uri.host
        "http://#{user}:#{password}@#{uri.host}:#{uri.port}#{uri.path}"
      end
    end

    def self.test_auth
      begin
        RestClient.get Api.url
      rescue Exception
        return false
      end
      true
    end

  end

  class OVFPackage
    include SAXMachine
    include RestResource
    
    element :link
    element :categoryName, :as => :category_name
    element :description
    element :diskFormatTypeUri, :as => :disk_format_type_uri
    element :diskSizeMb, :as => :dist_size_mb
    element :productName, :as => :product_name
    element :id, :as => :resource_id
    element :url


    #
    # enterprise can be either 1 or an Enterprise object
    #
    def self.all(enterprise = 1)
      if enterprise.is_a? Enterprise
        enterprise_id = enterprise.resource_id
      else
        enterprise_id = enterprise
      end
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{enterprise_id}/appslib/ovfpackages", :content_type => :xml))
      doc.search('//ovfPackage').each do |node|
        items << OVFPackage.parse(node.to_s)
      end
      items 
    end

    def self.find(enterprise_id = 1, package_id = 1)
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{enterprise_id}/appslib/ovfpackages/#{package_id}"))
      OVFPackage.parse(doc.root.to_s)
    end
  end
  
  class Datacenter
    include SAXMachine
    include RestResource

    resource_path '/admin/datacenters'
    resource_name 'datacenter'

    element :id, :as => :datacenter_id
    element :name
    element :ramSoft, :as => :ram_soft
    element :ramHard, :as => :ram_hard
    element :cpuSoft, :as => :cpu_soft
    element :cpuHard, :as => :cpu_hard
    element :storageSoft, :as => :storage_soft
    element :storageHard, :as => :storage_hard
    element :repositorySoft, :as => :repository_soft
    element :repositoryHard, :as => :repository_hard
    element :publicIpsSoft, :as => :public_ip_soft
    element :publicIpsHard, :as => :public_ip_hard
    element :hdSoft, :as => :hd_soft
    element :hdHard, :as => :hd_hard
    element :vlanSoft, :as => :vlan_soft
    element :vlanHard, :as => :vlan_hard
    element :location

    #
    # Return Datacenter Statistics
    # RAM in MB
    # HD in GB
    #
    def stats
      s = {
        :free_hd => 0, 
        :real_hd => 0,
        :used_hd => 0, 
        :machines => 0,
        :free_ram => 0,
        :real_ram => 0,
        :used_ram => 0,
        :real_cpus => 0,
        :virtual_machines => 0,
      }
      Datacenter.all.each do |dc|
        dc.racks.each do |rack|
          rack.machines.each do |m|
            s[:machines] += 1
            s[:used_ram] += m.ram_used.to_i
            s[:real_ram] += m.real_ram.to_i
            s[:real_cpus] += m.real_cpu.to_i
            s[:used_hd] += m.hd_used.to_i.bytes.to.gigabytes.to_f.round
            s[:real_hd] += m.real_hd.to_i.bytes.to.gigabytes.to_f.round
            m.virtual_machines.each do |vm|
              s[:virtual_machines] += 1
            end
          end
        end
      end
      s[:free_ram] = s[:real_ram] - s[:used_ram]
      s[:free_hd] = s[:real_hd] - s[:used_hd]
      return s
    end

    def self.create(attributes)
      if attributes[:remote_services].nil?
        attributes[:remote_services] = WeBee::RemoteService.create_for_host(Api.host)
      end
      xm = Builder::XmlMarkup.new
      xm.datacenter {
        xm.name attributes[:name]
        xm.location(attributes[:location] ||  'California, USA')
        xm.cpuSoft(attributes[:cpu_soft] || "0")
        xm.cpuHard(attributes[:cpu_hard] || "0")
        xm.vlanSoft(attributes[:vlan_soft] || "0")
        xm.vlanHard(attributes[:vlan_hard] || "0")
        xm.ramSoft(attributes[:ram_soft] || "0")
        xm.ramHard(attributes[:ram_hard] || "0")
        xm.repositorySoft(attributes[:repository_soft] || "0")  
        xm.repositoryHard(attributes[:repository_hard] || "0") 
        xm.publicIpsSoft(attributes[:public_ip_soft] || "0" ) 
        xm.publicIpsHard(attributes[:public_ip_hard] || "0" ) 
        xm.hdSoft(attributes[:hd_soft] || "0")
        xm.hdHard(attributes[:hd_hard] || "0")
        xm.storageSoft(attributes[:storage_soft] || "0")
        xm.storageHard(attributes[:storage_hard] || "0")
        xm.remoteServices {
          attributes[:remote_services].each do |rs|
            xm.remoteService {
              xm.uri  rs.uri
              xm.type rs.rs_type
            }
          end
        }
      }
      res = RestClient.post(Api.url + '/admin/datacenters', xm.target!, :content_type => :xml)
      Datacenter.parse(res)
    end

    #
    # Return all the Datacenters matching name
    #
    def self.find_by_name(name, options = {})
      Datacenter.all.find_all { |dc| dc.name =~ /#{name}/ }
    end

    def racks
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/datacenters/#{@datacenter_id}/racks", :accept => :xml))
      doc.search 
      doc.search('//rack').each do |node|
        rack = Rack.parse(node.to_s)
        rack.datacenter_id = @datacenter_id
        items << rack
      end
      items 
    end

    def add_rack(params)
      Rack.create datacenter_id, params
    end

    def discover_machine(params)
      p = {}
      p[:ip] = params[:ip]
      p[:hypervisortype] = params[:hypervisortype] || 'kvm'
      p[:user] = params[:user] || 'user'
      p[:password] = params[:secret] || 'secret'
      p[:port] = params[:port] || '8889'
      p[:virtual_switch] = params[:virtual_switch]
      res = RestClient.get Api.url + "/admin/datacenters/#{datacenter_id}/action/discover", :params => p, :content_type => :xml
      machine = Machine.parse res
    end

    #
    # Find a WeBee::VirtualMachine by name in this
    # Datacenter. 
    #
    # returns a WeBee::VirtualMachine 
    #
    def find_vms_by_name(regexp)
      matches = []
      self.racks.each do |rack|
        rack.machines.each do |m|
          m.virtual_machines.each do |vm|
            matches << vm if vm.name =~ /#{regexp}/i
          end
        end
      end
      matches
    end

  end

  class RemoteService
    attr_reader :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def uri
      @attributes[:uri]
    end

    def rs_type
      @attributes[:rs_type]
    end

    def self.from_type(address, type, use_ssl = false)
      rs_type_map = {
        'STORAGE_SYSTEM_MONITOR' => 'ssm',
        'VIRTUAL_FACTORY' => 'virtualfactory',
        'VIRTUAL_SYSTEM_MONITOR' => 'vsm',
        'NODE_COLLECTOR' => 'nodecollector',
        'APPLIANCE_MANAGER' => 'am',
      }
      case type
        when RemoteServiceType::BPM_SERVICE
          RemoteService.new :uri => "tcp://#{address}:61616", :rs_type => type
        when RemoteServiceType::DHCP_SERVICE
          RemoteService.new :uri => "omapi://#{address}:7911", :rs_type => type
        else
          if use_ssl
            RemoteService.new :uri => "https://#{address}:443", :rs_type => type
          else
            RemoteService.new :uri => "http://#{address}:80/#{rs_type_map[type]}", :rs_type => type
          end
      end
    end

    def self.create_for_host(address, use_ssl = false)
      items = []
      %w(
        STORAGE_SYSTEM_MONITOR
        VIRTUAL_FACTORY
        VIRTUAL_SYSTEM_MONITOR
        NODE_COLLECTOR
        APPLIANCE_MANAGER
        DHCP_SERVICE
        BPM_SERVICE
      ).each do |t|
        items << RemoteService.from_type(address, t, use_ssl)
      end
      items
    end
  end

  class Rack
    include SAXMachine

    attr_accessor :datacenter_id

    element :id, :as => :rack_id
    element :longDescription, :as => :long_description
    element :name
    element :nrsq
    element :shortDescription, :as => :short_description
    element :vlanIdMax, :as => :vlan_id_max
    element :vlanIdMin, :as => :vlan_id_min
    element :vlanPerVdcExpected, :as => :vlan_per_vdc_expected
    element :vlansIdAvoided, :as => :vlan_id_avoided
    element :haEnabled, :as => :ha_enabled

    def self.create(datacenter_id, attributes)
      xml = attributes.to_xml(:root => 'rack')
      res = RestClient.post(Api.url + "/admin/datacenters/#{datacenter_id}/racks", xml, :content_type => :xml, :accept => :xml)
      r = Rack.parse(res)
      r.datacenter_id = datacenter_id
      r
    end

    def delete
      RestClient.delete(Api.url + "/admin/datacenters/#{datacenter_id}/racks/#{rack_id}", :content_type => :xml)
    end

    def add_machine(machine)
      res = RestClient.post Api.url + "/admin/datacenters/#{datacenter_id}/racks/#{rack_id}/machines", machine.to_xml, :content_type => :xml
    end

    def machines
      u = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/datacenters/#{datacenter_id}/racks/#{rack_id}/machines", :content_type => :xml))
      doc.search('//machine').each do |node|
        u << Machine.parse(node.to_s)
      end
      u
    end

  end

  class Datastore
    include SAXMachine

    element :id, :as => :datastore_id
    element :directory
    element :rootPath, :as => :root_path
    element :enabled
    element :name
    element :size
    element :usedSize, :as => :used_size

    def to_xml
      xm = Builder::XmlMarkup.new
      xm.datastore {
        xm.name name
        xm.directory directory
        xm.rootPath root_path
        xm.enabled enabled
        xm.size size
        xm.usedSize used_size
      }
    end

  end

  class Machine
    include SAXMachine

    attr_accessor :raw
    attr_accessor :datacenter_id

    element :id, :as => :machine_id
    element :description
    element :ip
    element :ipService, :as => :ip_service
    element :name
    element :password
    element :user
    element :realCpu, :as => :real_cpu
    element :realHd, :as => :real_hd # in Bytes
    element :realRam, :as => :real_ram # in MB
    element :state
    element :type, :as => :hypervisortype
    element :cpu
    element :cpuRatio, :as => :cpu_ratio
    element :cpuUsed, :as => :cpu_used
    element :hd
    element :hdUsed, :as => :hd_used
    element :ram
    element :ramUsed, :as => :ram_used
    element :virtualSwitch, :as => :virtual_switch
    elements :datastore, :as => :datastores, :class => Datastore
    element :link, :value => :href, :as => :virtual_machines_url, :with => {:title => "virtualmachines" }
    element :link, :value => :href, :as => :rack_url, :with => { :rel => "rack" }

    def virtual_switches
      virtual_switch.split('/')
    end

    def to_xml
      xm = Builder::XmlMarkup.new
      xm.machine {
        xm.name name
        xm.description description
        xm.ip ip
        xm.ipService ip_service
        xm.user user
        xm.password password
        xm.realCpu real_cpu
        xm.realHd real_hd
        xm.realRam real_ram
        xm.state state
        xm.type hypervisortype
        xm.cpu cpu
        xm.cpuRatio cpu_ratio
        xm.cpuUsed cpu_used
        xm.hd hd
        xm.hdUsed hd_used
        xm.ram ram
        xm.ramUsed ram_used
        xm.virtualSwitch virtual_switch
        xm.datastores {
          datastores.each do |ds|
            xm.datastore {
              xm.name ds.name
              xm.directory ds.directory
              xm.rootPath ds.root_path
              xm.enabled ds.enabled
              xm.size ds.size
              xm.usedSize ds.used_size
            }
          end
        }
      }
      xm.target!
    end

    def rack
      doc = Nokogiri.parse(RestClient.get(Api.build_url(rack_url) , :accept => :xml))
      Rack.parse doc.root.to_s
    end

    def virtual_machines
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.build_url(virtual_machines_url) , :accept => :xml))
      doc.search('//virtualMachine').each do |node|
        items << VirtualMachine.parse(node.to_s)
      end
      items 
    end

    def find_vms_by_name(name)
      matches = []
        self.virtual_machines.each do |vm|
          matches << vm if vm.name =~ /#{regexp}/i
        end
      matches
    end

  end

  class RemoteServiceType
    VIRTUAL_FACTORY = 'VIRTUAL_FACTORY'
    STORAGE_SYSTEM_MONITOR = 'STORAGE_SYSTEM_MONITOR'
    VIRTUAL_SYSTEM_MONITOR = 'VIRTUAL_SYSTEM_MONITOR'
    NODE_COLLECTOR = 'NODE_COLLECTOR'
    APPLIANCE_MANAGER = 'APPLIANCE_MANAGER'
    DHCP_SERVICE = 'DHCP_SERVICE'
    BPM_SERVICE = 'BPM_SERVICE'
  end

  #
  # A Virtual Datacenter Network
  # FIXME: Unimplemented
  #
  class VDCNetwork
    include SAXMachine
    element :id, :as => :vdc_id
    element :name
    element :gateway
    element :address
    element :mask
    element :defaultNetwork, :as => :default_network

    def self.create(attributes)
      xml = attributes.to_xml(:root => 'network')
      VDCNetwork.parse(xml)
    end

    def to_xml
    end
  end
  
  #
  # A virtual datacenter
  # FIXME: Unimplemented
  class VDC
    include SAXMachine
    element :id, :as => :vdc_id
    element :name
    element :ramSoft, :as => :ram_soft
    element :ramHard, :as => :ram_hard
    element :cpuSoft, :as => :cpu_soft
    element :cpuHard, :as => :cpu_hard
    element :storageSoft, :as => :storage_soft
    element :storageHard, :as => :storage_hard
    element :publicIpsSoft, :as => :public_ip_soft
    element :publicIpsHard, :as => :public_ip_hard
    element :hdSoft, :as => :hd_soft
    element :hdHard, :as => :hd_hard
    element :vlanSoft, :as => :vlan_soft
    element :vlanHard, :as => :vlan_hard
    element :hypervisorType, :as => :hypervisortype
    element :network, :class => VDCNetwork
    element :link, :value => :href, :as => :datacenter_url, :with => {:rel => "datacenter" }
    element :link, :value => :href, :as => :enterprise_url, :with => {:rel => "enterprise" }

    def self.create(attributes)
      datacenter = attributes[:datacenter].datacenter_id
      enterprise = attributes[:enterprise].resource_id
      if attributes[:network].nil?
        net = VDCNetwork.new
        net.name = 'defaultNetwork'
        net.gateway = '192.168.1.1'
        net.address = '192.168.1.0'
        net.mask = '24'
        net.default_network = true
        attributes[:network] = net
      end
      xm = Builder::XmlMarkup.new
      xm.virtualDatacenter {
        xm.name attributes[:name]
        xm.cpuSoft(attributes[:cpu_soft] || "0")
        xm.cpuHard(attributes[:cpu_hard] || "0")
        xm.vlanSoft(attributes[:vlan_soft] || "0")
        xm.vlanHard(attributes[:vlan_hard] || "0")
        xm.ramSoft(attributes[:ram_soft] || "0")
        xm.ramHard(attributes[:ram_hard] || "0")
        xm.publicIpsSoft(attributes[:public_ip_soft] || "0" ) 
        xm.publicIpsHard(attributes[:public_ip_hard] || "0") 
        xm.hdSoft(attributes[:hd_soft] || "0")
        xm.hdHard(attributes[:hd_hard] || "0" )
        xm.storageSoft(attributes[:storage_soft] || "0")
        xm.storageHard(attributes[:storage_hard] || "0")
        xm.hypervisorType attributes[:hypervisortype]
        xm.network {
          xm.name(attributes[:network].name || 'defaultNetwork')
          xm.gateway(attributes[:network].gateway || '192.168.1.1')
          xm.address(attributes[:network].address || '192.168.1.0')
          xm.mask(attributes[:network].mask || '24')
          xm.defaultNetwork(attributes[:network].default_network || true)
        }
      }
      res = RestClient.post(Api.url + "/cloud/virtualdatacenters/?datacenter=#{datacenter}&enterprise=#{enterprise}", xm.target!, :content_type => :xml)
      VDC.parse(res)
    end

    def to_xml
      xm = Builder::XmlMarkup.new
      xm.virtualDatacenter {
        xm.name name
        xm.cpuSoft(cpu_soft || "0")
        xm.cpuHard(cpu_hard || "0")
        xm.vlanSoft(vlan_soft || "0")
        xm.vlanHard(vlan_hard || "0")
        xm.ramSoft(ram_soft || "0")
        xm.ramHard(ram_hard || "0")
        xm.repositorySoft(repository_soft || "0")  
        xm.repositoryHard(repository_hard || "0") 
        xm.publicIpsSoft(public_ip_soft || "0" ) 
        xm.publicIpsHard(public_ip_hard || "0" ) 
        xm.hdSoft(hd_soft || "0")
        xm.hdHard(hd_hard || "0")
        xm.storageSoft(storage_soft || "0")
        xm.storageHard(storage_hard || "0")
        xm.network {
          xm.name(network.name || 'defaultNetwork')
          xm.gateway(network.gateway || '192.168.1.1')
          xm.address(network.address || '192.168.1.0')
          xm.mask(network.mask || '24')
          xm.defaultNetwork(netowork.default_network || true)
        }
      }
      xm.target!
    end

    def self.all(params = {})
      items = []
      if params.empty?
        doc = Nokogiri.parse(RestClient.get(Api.url + "/cloud/virtualdatacenters", :accept => :xml))
        doc.search('//virtualDatacenter').each do |node|
          items << VDC.parse(node.to_s)
        end
      else
        extra = []
        if params[:enterprise_id]
          extra << "enterprise=#{params[:enterprise_id]}"
        end
        if params[:datacenter_id]
          extra << "datacenter=#{params[:datacenter_id]}"
        end
        doc = Nokogiri.parse(RestClient.get(Api.url + "/cloud/virtualdatacenters?#{extra.join('&')}", :accept => :xml))
        doc.search('//virtualDatacenter').each do |node|
          items << VDC.parse(node.to_s)
        end
      end
      items
    end

    def self.find_by_name(name, options = {})
      VDC.all(options).find_all { |vdc| vdc.name =~ /#{name}/ }
    end

    def delete
      RestClient.delete(Api.url + "/cloud/virtualdatacenters/#{vdc_id}")
    end
    
    #
    # List all the virtual appliances in this virtual datacenter
    #
    def virtual_appliances
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/cloud/virtualdatacenters/#{vdc_id}/virtualappliances", :accept => :xml))
      doc.search('//virtualAppliance').each do |node|
        vapp = VirtualAppliance.parse(node.to_s)
        vapp.vdc_id = vdc_id
        items << vapp
      end
      items
    end

  end

  class VirtualAppliance
    include SAXMachine
    
    attr_accessor :vdc_id

    element :name
    element :highDisponibility, :as => :high_disponibility
    element :error
    element :publicApp, :as => :public_app
    element :state
    element :subState, :as => :sub_state
    element :id, :as => :virtual_appliance_id

    def virtual_machines
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/cloud/virtualdatacenters/#{vdc_id}/virtualappliances/#{virtual_appliance_id}/virtualmachines", :accept => :xml))
      doc.search('//virtualMachine').each do |node|
        items << VirtualMachine.parse(node.to_s)
      end
      items
    end
  end

  class DatacenterLimit
    include SAXMachine

    element :id, :as => :datacenter_limit_id
    element :ramSoft, :as => :ram_soft
    element :ramHard, :as => :ram_hard
    element :cpuSoft, :as => :cpu_soft
    element :cpuHard, :as => :cpu_hard
    element :storageSoft, :as => :storage_soft
    element :storageHard, :as => :storage_hard
    element :repositorySoft, :as => :repository_soft
    element :repositoryHard, :as => :repository_hard
    element :publicIpsSoft, :as => :public_ip_soft
    element :publicIpsHard, :as => :public_ip_hard
    element :hdSoft, :as => :hd_soft
    element :hdHard, :as => :hd_hard
    element :vlanSoft, :as => :vlan_soft
    element :vlanHard, :as => :vlan_hard
    element :idEnterprise, :as => :enterprise_id
    element :idDataCenter, :as => :datacenter_id

  end

  class Enterprise
    include SAXMachine
    include RestResource
    
    resource_path '/admin/enterprises'
    resource_name 'enterprise'

    element :id, :as => :resource_id
    element :name
    element :ramSoft, :as => :ram_soft
    element :ramHard, :as => :ram_hard
    element :cpuSoft, :as => :cpu_soft
    element :cpuHard, :as => :cpu_hard
    element :storageSoft, :as => :storage_soft
    element :storageHard, :as => :storage_hard
    element :repositorySoft, :as => :repository_soft
    element :repositoryHard, :as => :repository_hard
    element :publicIpsSoft, :as => :public_ip_soft
    element :publicIpsHard, :as => :public_ip_hard
    element :hdSoft, :as => :hd_soft
    element :hdHard, :as => :hd_hard
    element :vlanSoft, :as => :vlan_soft
    element :vlanHard, :as => :vlan_hard
    element :isReservationRestricted, :as => :is_reservation_restricted
    element :link, :value => :href, :as => :limits_url, :with => {:rel => "limits" }
    
    def limits
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{resource_id}/limits"))
      doc.search('//limit').each do |node|
        items << DatacenterLimit.parse(node.to_s)
      end
      items
    end

    def delete
      RestClient.delete(Api.url + "/admin/enterprises/#{resource_id}")
    end

    #
    # may raise Exception if recuest is not successful
    #
    def self.create(attributes = {})
      xm = Builder::XmlMarkup.new
      xm.enterprise {
        xm.name attributes[:name]
        xm.cpuSoft(attributes[:cpu_soft] || "0")
        xm.cpuHard(attributes[:cpu_hard] || "0")
        xm.vlanSoft(attributes[:vlan_soft] || "0")
        xm.vlanHard(attributes[:vlan_hard] || "0")
        xm.ramSoft(attributes[:ram_soft] || "0")
        xm.ramHard(attributes[:ram_hard] || "0")
        xm.repositorySoft(attributes[:repository_soft] || "0")  
        xm.repositoryHard(attributes[:repository_hard] || "0") 
        xm.publicIpsSoft(attributes[:public_ip_soft] || "0" ) 
        xm.publicIpsHard(attributes[:public_ip_hard] || "0" ) 
        xm.hdSoft(attributes[:hd_soft] || "0")
        xm.hdHard(attributes[:hd_hard] || "0")
        xm.storageSoft(attributes[:storage_soft] || "0")
        xm.storageHard(attributes[:storage_hard] || "0")
      }
      res = RestClient.post(Api.url + '/admin/enterprises', xm.target!, :content_type => :xml)
      Enterprise.parse(res)
    end

    def self.find_by_name(name, options = {})
      Enterprise.all(options).find_all { |e| e.name =~ /#{name}/ }
    end

    def ovf_packages
      WeBee::OVFPackage.all(resource_id)
    end

    def users
      col = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{resource_id}/users"))
      doc.search('//user').each do |node|
        user = User.parse(node.to_s)
        col << user
        user.enterprise_id = resource_id
      end
      col 
    end

    def create_user(params)
      params[:enterprise] = self
      User.create params
    end

    def create_vdc(params)
      params[:enterprise] = self
      VDC.create(params)
    end

    def set_limits_for_datacenter(dc, params = {})
      datacenter = dc.datacenter_id
      xm = Builder::XmlMarkup.new
      xm.limit {
        xm.cpuSoft(params[:cpu_soft] || "0")
        xm.cpuHard(params[:cpu_hard] || "0")
        xm.vlanSoft(params[:vlan_soft] || "0")
        xm.vlanHard(params[:vlan_hard] || "0")
        xm.ramSoft(params[:ram_soft] || "0")
        xm.ramHard(params[:ram_hard] || "0")
        xm.repositorySoft(params[:repository_soft] || "0")  
        xm.repositoryHard(params[:repository_hard] || "0") 
        xm.publicIpsSoft(params[:public_ip_soft] || "0" ) 
        xm.publicIpsHard(params[:public_ip_hard] || "0" ) 
        xm.hdSoft(params[:hd_soft] || "0")
        xm.hdHard(params[:hd_hard] || "0")
        xm.storageSoft(params[:storage_soft] || "0")
        xm.storageHard(params[:storage_hard] || "0")
      }
      res = RestClient.post(Api.url + "/admin/enterprises/#{resource_id}/limits?datacenter=#{datacenter}", xm.target!, :content_type => :xml)
    end

    def vdcs
      VDC.all(:enterprise_id => resource_id)
    end

    def enterprise_id
      resource_id
    end

  end

  class User
    include SAXMachine

    attr_accessor :enterprise_id
    element :name
    element :surname
    element :email
    element :description
    element :nick
    element :active
    element :id, :as => :user_id
    element :link, :value => :href, :as => :virtual_machines_url, :with => {:title => "virtualmachines" }
    element :link, :value => :href, :as => :enterprise_url, :with => {:rel => "enterprise" }
    element :link, :value => :href, :as => :roles_url, :with => {:rel => "role" }

    #
    # May raise exception if request is not successful
    #
    def self.create(params)
      if params[:role]
        role = "<link rel='role' href='#{params[:role]}'/>"
        params.delete :role
      end
      eid = params[:enterprise].resource_id
      params.delete :enterprise
      xml = params.to_xml(:root => 'user')
      xml = xml.gsub('</user>', "#{role}</user>")
      res = RestClient.post(Api.url + "/admin/enterprises/#{eid}/users", xml, :content_type => :xml, :accept => :xml)
      user = User.parse(res)
      user.enterprise_id = eid
      user
    end

    def delete
      RestClient.delete(Api.url + "/admin/enterprises/#{enterprise_id}/users/#{user_id}")
    end

    def self.find(user_id, enterprise)
      if enterprise.is_a? Enterprise
        enterprise_id = enterprise.resource_id
      else
        enterprise_id = enterprise
      end
      User.parse(RestClient.get(Api.url + "/admin/enterprises/#{enterprise_id}/users/#{user_id}"))
    end

    def self.all(enterprise = nil)
      if enterprise.is_a? Enterprise
        enterprise_id = enterprise.resource_id
      else
        enterprise_id = enterprise
      end
      if enterprise.nil?
        enterprise_id = '_'
      end
      u = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{enterprise_id}/users"))
      doc.search('//user').each do |node|
        user = User.parse(node.to_s)
        u << user
        user.enterprise_id = enterprise_id
      end
      u
    end

    def virtual_machines
      items = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{enterprise_id}/users/#{user_id}/action/virtualmachines" , :accept => :xml))
      doc.search('//virtualMachine').each do |node|
        items << VirtualMachine.parse(node.to_s)
      end
      items 
    end

    def enterprise
      doc = Nokogiri.parse(RestClient.get(Api.build_url(enterprise_url) , :accept => :xml))
      Enterprise.parse doc.root.to_s
    end

  end

  class VirtualMachine
    include SAXMachine

    element :name
    element :description
    element :ram
    element :cpu
    element :hd
    element :vdrpPort, :as => :vrdp_port
    element :state
    element :highDisponibility, :as => :high_disponibility
    element :password
    element :id, :as => :virtualmachine_id
    element :idType, :as => :id_type
    element :link, :value => :href, :as => :vdc_url, :with => {:rel => "virtualdatacenter" }
    element :link, :value => :href, :as => :enterprise_url, :with => {:rel => "enterprise" }
    element :link, :value => :href, :as => :machine_url, :with => {:rel => "machine" }
    element :link, :value => :href, :as => :user_url, :with => {:rel => "user" }

    def vdc
      return nil if not managed?
      doc = Nokogiri.parse(RestClient.get(Api.build_url(vdc_url) , :accept => :xml))
      Rack.parse doc.root.to_s
    end

    def managed?
      id_type.eql?("0") ? false : true
    end
    
    def enterprise
      return nil if not managed?
      doc = Nokogiri.parse(RestClient.get(Api.build_url(enterprise_url) , :accept => :xml))
      Enterprise.parse doc.root.to_s
    end

    def machine
      doc = Nokogiri.parse(RestClient.get(Api.build_url(machine_url) , :accept => :xml))
      Machine.parse doc.root.to_s
    end

    def user
      doc = Nokogiri.parse(RestClient.get(Api.build_url(user_url) , :accept => :xml))
      User.parse doc.root.to_s
    end

  end

  class UserRole

    def self.cloud_admin
      Api.url + '/admin/roles/1'
    end
    
    def self.user
      Api.url + '/admin/roles/2'
    end
    
    def self.enterprise_admin
      Api.url + '/admin/roles/3'
    end

  end

end

