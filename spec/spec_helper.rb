begin
  require 'spec'
  require 'json'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'riakrest'
include RiakRest

SERVER_URI = 'http://localhost:8002/jiak'  unless(defined?(SERVER_URI))
