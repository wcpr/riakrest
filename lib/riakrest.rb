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
# use. But we have to show the Core Client first since Resource is built on top
# of it.
#
# ===Core Client Interaction
# The primary Jiak constructs are represented by core Jiak classes:
# JiakClient :: Client used to make Jiak put, get, delete, and other calls.
# JiakBucket :: Bucket name and the data class stored in the bucket.
# JiakSchema :: The schema used by a Jiak server bucket.
# JiakData :: User-defined data to be stored.
# JiakObject :: The Jiak object wrapper that includes the user data.
# JiakLink :: Jiak link objects.
#
# ====Example Usage
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
# Why wasn't the Jiak server data updated? Because we didn't set the key on the
# JiakObject being sent, so to Jiak it looked like a new store. The easiest way
# to be sure we have the Jiak info we need is to ask for the Jiak object to be
# returned (with all the Jiak internals set) by the store method. Let's try
# again with callie.
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
# create resource objects. We'll do the same initial steps we did for Remy
# above. First we create a JiakData class and a JiakResource to hold it.
# <code>
#   PersonData = JiakDataHash.create(:name,:age)
#   class Person
#     include JiakResource
#     server   'http://localhost:8002/jiak'
#     resource :name => 'person', :data_class => PersonData
#   end
# </code>
# Next we create and store remy, check the name on the Jiak server, change and
# update remy's name, then check the name on the server again.
# <code>
#   remy = Person.create(:name => 'remy', :age => 10)
#   remy.store
#
#   puts remy.name                           # => "remy"
#   puts Person.get(remy.jiak.key).name      # => "remy"
#
#   remy.name = "Remy"
#   remy.update
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

