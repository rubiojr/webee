require 'rubygems'
require 'rest_client'
require 'sax-machine'
require 'nokogiri'
require 'active_support/core_ext/hash'
require 'uri'
require 'json'
require 'builder'

module WeBee 

  VERSION = '0.2'

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


  class Api
    class << self
      attr_accessor :user, :password, :url, :port, :host

      def url=(url)
        @url = build_url(url)
      end

      private
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
            puts rs
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
        items << Rack.parse(node.to_s)
      end
      items 
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
  end
  
  #
  # A virtual datacenter
  # FIXME: Unimplemented
  class VDC
    include SAXMachine
    element :id, :as => :vdc_id
    element :name
    element :network, :class => VDCNetwork
    element :hypervisorType, :as => :hypervisor_type

    def self.create(attributes)
      attributes[:network] = {
        :name => attributes[:network].name,
        :gateway => attributes[:network].gateway,
        :address => attributes[:network].address,
        :mask => attributes[:network].mask,
        :default_network => attributes[:network].default_network,
      }
      xml = attributes.to_xml(:root => 'network')
    end
  end

  class Enterprise
    include SAXMachine
    include RestResource
    
    resource_path '/admin/enterprises'
    resource_name 'enterprise'

    element :id, :as => :resource_id
    element :name

    def delete
      RestClient.delete(Api.url + "/admin/enterprises/#{resource_id}")
    end

    #
    # may raise Exception if recuest is not successful
    #
    def self.create(attributes = {})
      xml = attributes.to_xml(:root => 'enterprise')
      res = RestClient.post(Api.url + '/admin/enterprises', xml, :content_type => :xml, :accept => :xml)
      Enterprise.parse(res)
    end

    def self.find_by_name(name, options = {})
      Enterprise.all(options).find { |e| e.name =~ /#{name}/ }
    end

    def ovf_packages
      WeBee::OVFPackage.all(resource_id)
    end

    def users
      col = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{resource_id}/users"))
      doc.search('//user').each do |node|
        col << User.parse(node.to_s)
      end
      col 
    end

    def create_user(attributes)
      attributes[:enterprise] = self
      User.create attributes
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

    #
    # May raise exception if request is not successful
    #
    def self.create(attributes)
      if attributes[:role]
        role = "<link rel='role' href='#{attributes[:role]}'/>"
        attributes.delete :role
      end
      eid = attributes[:enterprise].resource_id
      attributes.delete :enterprise
      xml = attributes.to_xml(:root => 'user')
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
        u << User.parse(node.to_s)
      end
      u
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

