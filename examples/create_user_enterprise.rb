$: << '../lib'
require 'webee'
require 'md5'

WeBee::Api.user = 'admin'
WeBee::Api.password = 'password'
WeBee::Api.url = 'http://as-testing/api'

ent = WeBee::Enterprise.create :name => 'apient1'
WeBee::User.create :name => 'API User 1',
                  :role => WeBee::UserRole.cloud_admin,
                  :enterprise => ent,
                  :password => MD5.hexdigest('apiuser1'),
                  :surname => 'mysurname1', #optional
                  :email => 'apiuser1@apient.com',
                  :locale => 'en_US',
                  :nick => 'apiuser1',
                  :active => 'true'  #optional
