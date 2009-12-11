require File.dirname(__FILE__) + '/example_helper.rb'

# Simple JiakData class with a couple of attributes
class PersonData
  include JiakData
  attr_accessor :name, :age
end

client = JiakClient.new(SERVER_URI)
bucket = JiakBucket.new('people',PersonData)

puts bucket.name                              # => 'people'
puts bucket.data_class                        # => PeopleData
puts bucket.data_class.schema                 # => JiakSchema of data
puts bucket.schema                            # => Same as above

# The default schema for a Riak bucket is the WIDE_OPEN schema.
puts client.schema(bucket)                    # => JiakSchema of server bucket.
client.set_schema(bucket)
puts client.schema(bucket)                    # => Server schema now data schema

# Create and store Jiak objects. Keys are server generated. JiakObjects with
# Riak context are returned.
remy = client.store(JiakObject.new(:bucket => bucket,
                                   :data => PersonData.new(:name => "remy",
                                                            :age => 10)),
                    :return => :object)
callie = client.store(JiakObject.new(:bucket => bucket,
                                     :data => PersonData.new(:name => "Callie",
                                                             :age => 12)),
                      :return => :object)

puts remy.key                                 # => server generated key
puts remy.data                                # => PersonData
puts remy.data.name                           # => remy
puts remy.data.age                            # => 10

# Change data and show server value
remy.data.name = "Remy"
client.store(remy)
puts client.get(bucket,remy.key).data.name    # => Remy

# Add a link from remy to callie tagged as sister, and show links
remy << JiakLink.new(bucket,callie.key,'sister')
client.store(remy)
puts remy.links                               # => JiakLink

# Follow the sister link and test that callie is in the returned array
sisters = client.walk(bucket,remy.key,
                      QueryLink.new(bucket,'sister'),PersonData)
puts sisters.include?(callie)                 # => true
puts sisters.size                             # => 1
puts sisters[0].data.name                     # => "Callie"

# Clean-up
client.delete(bucket,remy.key)
client.delete(bucket,callie.key)
