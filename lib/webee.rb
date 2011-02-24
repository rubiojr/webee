require 'rubygems'
require 'rest_client'
require 'sax-machine'
require 'nokogiri'
require 'pp'
require 'active_support/core_ext/hash'
require 'uri'

module WeBee 

  VERSION = '0.1'

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

  end

  class Enterprise
    include SAXMachine

    element :id, :as => :enterprise_id
    element :name

    #
    # Warning: this is very resource intensive
    #
    def self.all(options = {})
      e = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises"))
      page = options[:page]
      pages = doc.search('//totalSize').text.to_i
      1.upto(pages) do |p|
        doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises?page=#{p}"))
        doc.search('//enterprise').each do |node|
          e << Enterprise.parse(node.to_s)
        end
      end
      e
    end

    #
    # may raise Exception if recuest is not successful
    #
    def self.create(attributes = {})
      xml = attributes.to_xml(:root => 'enterprise')
      res = RestClient.post(Api.url + '/admin/enterprises', xml, :content_type => :xml, :accept => :xml)
      Enterprise.parse(res)
    end

    #
    # API BUG: if id is not it, we get 500 
    # (java.lang.NumberFormatException: For input string: "id)
    # 
    def self.find(id, options = {})
      Enterprise.parse(RestClient.get(Api.url + "/admin/enterprises/#{id}"))
    end

    def self.find_by_name(name, options = {})
      Enterprise.all(options).find { |e| e.name == name }
    end

    def users
      col = []
      doc = Nokogiri.parse(RestClient.get(Api.url + "/admin/enterprises/#{enterprise_id}/users"))
      doc.search('//user').each do |node|
        col << User.parse(node.to_s)
      end
      col 
    end

  end

  class User
    include SAXMachine

    element :name
    element :surname
    element :email
    element :description
    element :nick
    element :active

    #
    # May raise exception if request is not successful
    #
    def self.create(attributes)
      if attributes[:role]
        role = "<link rel='role' href='#{attributes[:role].gsub('admin:xabiquo@','')}'/>"
        attributes.delete :role
      end
      eid = attributes[:enterprise].enterprise_id
      attributes.delete :enterprise
      xml = attributes.to_xml(:root => 'user')
      xml = xml.gsub('</user>', "#{role}</user>")
      res = RestClient.post(Api.url + "/admin/enterprises/#{eid}/users", xml, :content_type => :xml, :accept => :xml)
      User.parse(res)
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

