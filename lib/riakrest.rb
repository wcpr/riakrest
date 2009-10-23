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

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || 
  $:.include?(File.expand_path(File.dirname(__FILE__)))

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
#
# ====Example Usage
# This example works at the Jiak core layer. See the Resource example below for
# an abstraction layered on top of this core.
# <code>
#   require 'riakrest'
#   include RiakRest
# </code>
# Get a client to talk to the Jiak server at a URI.
# <code>
#   client = JiakClient.new("http://localhost:8002/jiak")
# </code>
# Create a simple data class.
# <code>
#   Person = JiakDataHash.create(:name,:age)
# </code>
# Create a bucket to store Person data.
# <code>
#   bucket = JiakBucket.create('person',Person)
# </code>
# Set the schema of the Jiak server bucket to prepare for structured interaction.
# <code>
#   client.set_schema(bucket)
# </code>
# Create a user-defined data object.
# <code>
#   remy = Person.create(:name => "Remy", :age => 10)
# </code>
# Create a Jiak object wrapping the user-defined data.
# <code>
#   jobj = JiakObject.create(:bucket => bucket, :data => remy)
# </code>
# Store the Jiak data object on the server
# <code>
#   key = client.store(jobj)
# </code>
# Data in remy is accessible via accessors. Let's check remy and the Jiak
# server have the same value for the data name.
# <code>
#   puts remy.name                           # => "remy"
#   puts client.get(bucket,key).data.name    # => "remy"
# </code>
# Things look good. But the next interaction may surprise you.
# <code>
#   remy.name = "Remy"
#   client.store(jobj)
#   puts remy.name                           # => "Remy"
#   puts client.get(bucket,key).data.name    # => "remy"  ???
# </code>
# Why wasn't the data updated on the Jiak server? Because although we changed
# the data locally, we didn't alter the metadata in the JiakObject being sent,
# so to Jiak it looked like a new request to store info. The easiest way to be
# sure we get the Jiak metadata info is to ask for the Jiak object to be
# returned (which sets the Jiak internals) by the store method. Let's try again
# with a new data object.
# <code>
#   callie = Person.create(:name => "callie", :age => 12)
#   jobj = JiakObject.create(:bucket => bucket, :data => callie)
#   callie = client.store(jobj,{JiakClient::RETURN_BODY => true})
#   puts client.get(bucket,callie.key).data.name                 # => "callie"
#   callie.data.name = "Callie"
#   callie = client.store(callie,{JiakClient::RETURN_BODY => true})
#   puts client.get(bucket,callie.key).data.name                 # => "Callie"
# </code>
# Now all is right with the world. But let's delete Callie on our way out the door.
# <code>
#   client.delete(bucket,callie.key)
# </code>
#
# ===Resource Interaction
# Much of the above code can be abstracted into resource-based
# interaction. RiakRest provides a module JiakResource that allows you to
# create resource objects that encapsulate a lot of the cruft from above. We'll
# do the same initial steps we did for Remy above using resources. First we use
# JiakResource to hold our data and encapsulate the server interaction.
# <code>
#   class Person
#     include JiakResource
#     server   'http://localhost:8002/jiak'
#     resource :name => 'person',
#              :data_class => JiakDataHash.create(:name,:age)
#   end
# </code>
# Next we create and store remy, check the name on the Jiak server, change and
# update remy's name, then check the name on the server again.
# <code>
#   remy = Person.create(:name => 'remy', :age => 10)
#   remy.post
#
#   puts remy.name                           # => "remy"
#   puts Person.get(remy.jiak.key).name      # => "remy"
#
#   remy.name = "Remy"
#   remy.put
#
#   puts remy.name                           # => "Remy"
#   puts Person.get(remy.jiak.key).name      # => "Remy"
# </code>
# Finally, we'll delete remy.
# <code>
#   remy.delete
# </code>
# Ah, that feels better. Go forth and Riak!
module RiakRest
end

require 'riakrest/version'

require 'riakrest/core/exceptions'
require 'riakrest/core/jiak_bucket'
require 'riakrest/core/jiak_client'
require 'riakrest/core/jiak_data'
require 'riakrest/core/jiak_link'
require 'riakrest/core/jiak_object'
require 'riakrest/core/jiak_schema'

require 'riakrest/data/jiak_data_hash'

require 'riakrest/resource/jiak_resource'

class Array
  # Compare fields for equal string/symbol.to_s elements regardless of order.
  def same_fields?(arr)
    same = size == arr.size
    arr = arr.map{|f| f.to_s} if same
    same &&= map{|f| f.to_s}.reduce(true) do |same,value|
      same && arr.include?(value)
    end
    same
  end
end
