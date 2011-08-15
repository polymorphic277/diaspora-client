require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rspec'
require 'rack/test'


$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'diaspora-client'
require 'sqlite3'

ActiveRecord::Base.establish_connection({
  :adapter => 'sqlite3',
  :database => ':memory:'})

ActiveRecord::Schema.define do
  create_table :resource_servers do |t|
    t.string :client_id,     :limit => 40,  :null => false
    t.string :client_secret, :limit => 40,  :null => false
    t.string :host,          :limit => 127, :null => false
    t.timestamps
  end
  add_index :resource_servers, :host, :unique => true

  create_table :access_tokens do |t|
    t.integer :user_id, :null => false
    t.integer :resource_server_id, :null => false
    t.string  :access_token, :limit => 40, :null => false
    t.string  :refresh_token, :limit => 40, :null => false
    t.string  :uid, :limit => 40, :null => false
    t.datetime :expires_at
    t.timestamps
  end
  add_index :access_tokens, :user_id, :unique => true
  create_table :users do |t|
    t.timestamps
  end
end

RSpec.configure do |c|
  c.before(:each) do
    DiasporaClient.initialize_instance_variables
  end
end
