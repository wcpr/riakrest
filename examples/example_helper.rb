require 'rubygems' unless ENV['NO_RUBYGEMS']
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'riakrest'
include RiakRest

SERVER_URI = 'http://localhost:8002/jiak'

