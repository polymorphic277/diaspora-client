source "http://rubygems.org"
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.

gem 'sinatra'
gem 'activerecord'
gem 'oauth2', '0.4.1'
gem 'faraday'
gem 'jwt', '>= 0.1.3'
gem 'em-synchrony', :platform => :mri_19 
gem 'em-http-request', :platform => :mri_19
gem 'rack-fiber_pool', :require => 'rack/fiber_pool', :platform => :mri_19

group :development do
  gem "bundler", "~> 1.0.0"
  gem "jeweler", "~> 1.6.2"
  gem "rcov", ">= 0"
  gem 'ruby-debug19', :platform => :mri_19
  gem 'yard'
end

group :test, :development do
  gem 'rspec', '>= 2.0.0'
  gem "sqlite3"
  gem 'rack-test'
end
