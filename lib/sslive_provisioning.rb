require 'rubygems'
require 'active_resource'

module SsliveProvisioning
  class Error < StandardError; end
  class << self
    attr_accessor :user, :password, :host_format, :site_format, :domain_format, :protocol, :path
    attr_reader :account, :token
 
    # Sets the account name, and updates all the resources with the new domain.
    def account=(name)
      resources.each do |r|
        r.site = r.site_format % (host_format % [protocol, domain_format % name, r.path])
      end
      @account = name
    end
    
    def user=(value)
      resources.each do |r|
        r.user = value
      end
    end
    
    def password=(value)
      resources.each do |r|
        r.password = value
      end
    end
 
    def resources
      @resources ||= []
    end
    
    def setup
      settings = YAML.load_file("#{RAILS_ROOT}/config/sslive_api.yml").symbolize_keys
      self.account = settings[:account]
      self.user = settings[:user]
      self.password = settings[:password]
    end
  end
  
  self.host_format = '%s://%s/%s'
  self.domain_format = '%s.screenstepslive.com'
  self.protocol = 'https'
  
  class Base < ActiveResource::Base
    def self.inherited(base)
      SsliveProvisioning.resources << base
      class << base
        attr_accessor :site_format
        attr_accessor :path
      end
      base.site_format = '%s'
      super
    end
  end
  
  class User < Base
    self.path = 'admin'
    
    def self.find_by_email(email)
      user = self.find(:first, :params => {:email => email})
      return nil unless user
      self.find(user.id)
    end
    
    def self.find_by_login(login)
      user = self.find(:first, :params => {:login => login})
      return nil unless user
      self.find(user.id)
    end
    
    def self.readers(options = {})
      self.find(:all, :params => {:role => "reader"}.merge(options))
    end   
    
    def self.authors(options = {})
      self.find(:all, :params => {:role => "author"}.merge(options))
    end
    
    def self.admins(options = {})
      self.find(:all, :params => {:role => "admin"}.merge(options))
    end
    
    def self.api_access_users(options = {})
      self.find(:all, :params => {:role => "api access"}.merge(options))
    end
    
    def self.editors(options = {})
      self.find(:all, :params => {:role => "editor"}.merge(options))
    end
    
    def viewable_spaces
      self.spaces
    end
    
    def update_password(password)
      self.password = password
      self.password_confirmation = password
      self.save
    end
    
    def load_details
      
    end
  
  end
  
  def UserRoles
    self.path 'admin'
  end
  
  
  class Group < Base
    self.path = "admin"
    
    def self.find_by_title(title)
      group = self.find(:all).select {|g| g.title.downcase == title.downcase }
      self.find(group.id)
    end
    
    def members
      get("members")
    end
    
    def viewable_spaces
      self.spaces
    end
    
    def add_user(user)
      post("members", :id => user.id)
    end
    
    def remove_user(user)
      delete("members/#{user.id}")
    end
  end
  
  class Space < Base
    self.path = "admin"
    
    def self.find_by_title(title)
      self.find(:all).select {|s| s.title.downcase == title.downcase }
    end
    
    def add_user(user)
      post("viewers", :type => "user", :id => user.id)
    end
    
    def add_group(group)
      post("viewers", :type => "group", :id => group.id)
    end
    
    def remove_user(user)
      delete("viewers/#{user.id}", :type => "user")
    end
    
    def remove_group(group)
      delete("viewers/#{group.id}", :type => "group")
    end
    
  end
  
end


__END__
 
require 'sslive_provisioning'
SsliveProvisioning.account = 'youraccount'
SsliveProvisioning.user = 'username'
SsliveProvisioning.password = 'your_password'
 
# Create a user

# Required parameters: login, email, password, password_confirmation, role
# role can be one of admin, author, editor, reader, api access
# Optional parameters: first_name, last_name, time_zone

# Pass in :send_new_user_email => "1" if you want notifcations to be sent to new users once they are created.

SsliveProvisioning::User.create(:login => "login",
                             :email => "mail@mail.com",
                             :password => "password",
                             :password_confirmation => "password",
                             :role => "reader"
                             )

      
# quick user find options

SsliveProvisioning::User.find_by_login(login)
SsliveProvisioning::User.find_by_email(email)

# update a users password

user = SsliveProvisioning::User.find_by_email('mail@mail.com')
user.update_password("newpassword")


# get readers, admins, editors, etc. for an account

SsliveProvisioning::User.readers
SsliveProvisioning::User.api_access_users
SsliveProvisioning::User.admins
SsliveProvisioning::User.authors
SsliveProvisioning::User.editors
                             
# Create a group

# Required parameters: title

SsliveProvisioning::Group.create(:title => "My Group")         

# Add a user to a group (must have a role of reader or api access)

user = SsliveProvisioning::User.find_by_login("bob")
group = SsliveProvisioning::Group.find_by_title("My Group")
group.add_user(user)

# remove the user

group.remove_user(user)


# Add a user to a space (must have a role of reader or api access)

space = SsliveProvisioning::Space.find("#{id}")
space.add_user(user)

# remove the user

space.remove_user(user)

## Add a group to a space

space.add_group(group)

# remove the group

space.remove_group(group)

# see spaces a reader or api access user can access

user = SsliveProvisioning::User.find_by_email('mail@mail.com')
user.viewable_spaces

# see groups for a suer

user.groups

# see spaces for a group

group = SsliveProvisioning::Group.find_by_title('My Group')
group.spaces

# see users for a group

group.users