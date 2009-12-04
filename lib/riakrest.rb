# See README.rdoc for the RiakRest license.
begin
  require 'json'
rescue LoadError
  puts "\nRiakRest requires json for REST JSON messaging."
  puts "  Install with:  gem install json"
  puts
  exit
end

begin
  require 'restclient'
rescue LoadError
  puts "\nRiakRest requires the restclient gem for making REST calls."
  puts "  Install with:  gem install rest-client"
  exit
end

require 'uri'

dirname = File.dirname(__FILE__)
$:.unshift(dirname) unless
  $:.include?(dirname) || 
  $:.include?(File.expand_path(dirname))

# RiakRest provides structured, RESTful interaction with a Riak document data
# store. In Riak parlance, the HTTP/JSON interface to a Riak cluster is called
# Jiak. RiakRest provides two levels of Jiak interaction: Core Client and
# Resource. Core Client works directly with the Jiak level, whereas Resource is
# a resource-oriented abstraction on top of Core Client.
#
# ===Example
#  require 'riakrest'
#  include RiakRest
#
#  class People
#    include JiakResource
#    server 'http://localhost:8002/jiak'
#    attr_accessor :name, :age
#    auto_manage
#  end
#
#  remy = People.new(:name => 'Remy',:age => 10)       # (auto-post)
#  remy.age = 11                                       # (auto-update)
#
#  callie = People.new(:name => 'Callie', :age => 13)
#  remy.link(callie,'sister')
#
#  sisters = remy.query(People,'sister')
#  sisters[0].eql?(callie)                             # => true
#
#  remy.delete
#  callie.delete
#
# ===Core Client
# See JiakClient for Core Client example.
#
# Go forth and Riak!
module RiakRest
  version_file = File.join(File.dirname(__FILE__),"..","VERSION")
  VERSION = IO.read(version_file).chomp

  # Convenience method for checking validity of method options. If any of the
  # options in opt are not in valid, raise the exception listing the invalid
  # options in the message.
  def check_opts(opts,valid,exception)              # :nodoc:
    unless(opts.empty?)
      err = opts.inject({}) do |h,(k,v)|
        h[k] = v  unless(valid.include?(k))
        h
      end
      unless err.empty?
        raise exception, "unrecognized options: #{err.keys}"
      end
    end
    opts
  end
end

require 'riakrest/core/exceptions'
require 'riakrest/core/jiak_bucket'
require 'riakrest/core/jiak_client'
require 'riakrest/core/jiak_data'
require 'riakrest/core/jiak_data_fields'
require 'riakrest/core/jiak_link'
require 'riakrest/core/jiak_object'
require 'riakrest/core/jiak_schema'
require 'riakrest/core/query_link'

require 'riakrest/resource/jiak_resource'
require 'riakrest/resource/jiak_resource_pov'

# Extend Array with convenience methods for comparing array contents.
class Array   # :nodoc:
  # Compare arrays for same elements regardless of order.
  def same_elements?(arr)
    raise ArgumentError unless arr.is_a?(Array)
    (size == arr.size) && arr.reduce(true){|same,elem| same && include?(elem)}
  end

  # Compare arrays for same element.to_s values regardless of order.
  def same_fields?(arr)
    raise ArgumentError unless arr.is_a?(Array)
    (size == arr.size) && map{|f| f.to_s}.same_elements?(arr.map{|f| f.to_s})
  end
end
