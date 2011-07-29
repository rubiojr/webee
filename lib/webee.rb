require 'rubygems'
require 'rest_client'
require 'sax-machine'
require 'nokogiri'
require 'active_support/core_ext/hash'
require 'uri'

module WeBee 

  VERSION = '0.1'

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
      attr_accessor :user, :password, :url, :port

      def url=(url)
        @url = build_url(url)
      end

      private
      def build_url(url)
        port ||= 80
        uri = URI.parse(url)
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
    element :ramSoft
    element :ramHard
    element :cpuSoft
    element :cpuHard
    element :storageSoft
    element :storageHard
    element :repositorySoft
    element :repositoryHard
    element :publicIPSoft
    element :publicIPHard
    element :hdSoft
    element :hdHard
    element :vlanSoft
    element :vlanHard
    element :location

    def self.create(attributes)
      xml = attributes.to_xml(:root => 'datacenter')
      res = RestClient.post(Api.url + '/admin/datacenters', xml, :content_type => :xml, :accept => :xml)
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

