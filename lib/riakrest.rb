# See README.rdoc for the RiakRest license.
begin
  require 'json'
rescue LoadError
  raise "RiakRest requires json for REST JSON messaging."
end

begin
  require 'restclient'
rescue LoadError
  raise <<EOM
RiakRest requires the restclient gem for making REST calls.
  gem install rest-client
EOM
end

require 'uri'

dirname = File.dirname(__FILE__)
$:.unshift(dirname) unless
  $:.include?(dirname) || 
  $:.include?(File.expand_path(dirname))

# RiakRest provides structured, RESTful interaction with a Riak document
# store. In Riak parlance, this JSON data exchange is called Jiak. RiakRest
# provides two levels of interaction: Core Client and Resource. Core Client
# interaction works down at the Jiak level and so exposes Jiak
# internals. Resource interaction abstracts above that and is much easier to
# use. But we'll show the Core Client first since Resource is built on top of
# it.
#
# ===Core Client Interaction
# Primary Jiak constructs are represented by core Jiak classes:
# JiakClient :: Client used to make Jiak store, get, delete, and other calls.
# JiakBucket :: Bucket name and the data class stored in the bucket.
# JiakSchema :: Schema used by a Jiak server bucket.
# JiakData :: Class to define user data to be stored on a Jiak server.
# JiakObject :: Jiak object wrapper that includes the user-defined data.
# JiakLink :: Jiak link objects for associations between Jiak server data.
# QueryLink :: Link objects to query Jiak link associations.
#
# ====Example Usage
# This example works at the Jiak core layer. See the Resource example below for
# an abstraction layered on top of this core.
# <code>
#   require 'riakrest'
#   include RiakRest
# </code>
# Create a simple class to hold Person data.
# <code>
#   Person = JiakDataHash.create(:name,:age)
# </code>
# Create a client, a bucket to hold the data, and set the bucket schema for
# structured interaction.
# <code>
#   client = JiakClient.new("http://localhost:8002/jiak")
#   bucket = JiakBucket.new('person',Person)
#   client.set_schema(bucket)
# </code>
# Wrap a Person data object in a JiakObject and store it. Check the data on the
# server to see it's really there.
# <code>
#   remy = client.store(JiakObject.new(:bucket => bucket,
#                                      :data => Person.new(:name => "remy",
#                                                           :age => 10)),
#                       :object => true)
#   puts client.get(bucket,remy.key).data.name         # => "remy"
# </code>
# Change the data via accessors and update. Again, we print the server value.
# <code>
#   remy.data.name                                     # => "remy"
#   remy.data.name = "Remy"
#   client.store(remy)
#   puts client.get(bucket,remy.key).data.name         # => "Remy"
# </code>
# Let's add another person and a link between them.
# <code>
#   callie = client.store(JiakObject.new(:bucket => bucket,
#                                        :data => Person.new(:name => "Callie",
#                                                            :age => 12)),
#                         :object => true)
#   remy << JiakLink.new(bucket,callie.key,'sister')
#   client.store(remy)
# </code>
# Now we can get callie as the sister of remy:
# <code>
#   sisters = client.query(bucket,remy.key,QueryLink.new(bucket,'sister'),Person)
#   sisters[0].eql?(callie)                           # => true
# </code>
# Finally, we'll delete the objects on the way out the door.
# <code>
#   client.delete(bucket,remy.key)
#   client.delete(bucket,callie.key)
# </code>
#
# ===Resource Interaction
# Much of the above code can be abstracted into resource-based
# interaction. RiakRest provides a module JiakResource that allows you to
# create resource objects that encapsulate a lot of the cruft of core client
# interaction. We'll do the same steps as above using resources.
# <code>
#  require 'riakrest'
#  include RiakRest
# 
#  PersonData = JiakDataHash.create(:name,:age)
#  PersonData.keygen :name
# 
#  class Person
#    include JiakResource
#    server      'http://localhost:8002/jiak'
#    group       'people'
#    data_class  PersonData
#    auto_post   true
#    auto_update true
#  end
# 
#  remy = Person.new(:name => 'remy',:age => 10) #            (auto-post)
#  puts remy.name                                # => "remy"  (auto-update)
# 
#  puts Person.get('remy').name                  # => "remy"  (from Jiak server)
#  puts Person.get('remy').age                   # => 10      (from Jiak server)
#
#  remy.age = 11                                 #            (auto-update)
#  puts Person.get('remy').age                   # => 11      (from Jiak server)
#
#  callie = Person.new(:name => 'Callie', :age => 13)
#  remy.link(callie,'sister')
#
#  sisters = remy.query(Person,'sister')
#  puts sisters[0].eql?(callie)                  # => true
#
#  remy.delete
#  callie.delete
# </code>
# Ah, that feels better. Go forth and Riak!
module RiakRest
  version_file = File.join(File.dirname(__FILE__),"..","VERSION")
  VERSION = IO.read(version_file).chomp

  # Convenience method for checking validity of method options. If any of the
  # options in opt are not in valid, raise the exception with the invalid
  # options in the message.
  def check_opts(opts,valid,exception)
    err = opts.select {|k,v| !valid.include?(k)}
    unless err.empty?
      raise exception, "unrecognized options: #{err.keys}"
    end
    opts
  end
end

require 'riakrest/core/exceptions'
require 'riakrest/core/jiak_bucket'
require 'riakrest/core/jiak_client'
require 'riakrest/core/jiak_data'
require 'riakrest/core/jiak_link'
require 'riakrest/core/jiak_object'
require 'riakrest/core/jiak_schema'
require 'riakrest/core/query_link'

require 'riakrest/data/jiak_data_hash'
require 'riakrest/resource/jiak_resource'

# Extend Array with convenience methods for comparing array contents.
class Array
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
