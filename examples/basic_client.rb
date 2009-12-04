require File.dirname(__FILE__) + '/example_helper.rb'

# Simple Jiak data class
class PersonData
  include JiakData
  attr_accessor :name, :age
end

client = JiakClient.new(SERVER_URI)
bucket = JiakBucket.new('people',PersonData)
client.set_schema(bucket)

# Create and store a Jiak object. Key is server generated. Object with Riak
# context is returned.
remy = client.store(JiakObject.new(:bucket => bucket,
                                   :data => PersonData.new(:name => "remy",
                                                            :age => 10)),
                    :return => :object)
callie = client.store(JiakObject.new(:bucket => bucket,
                                     :data => PersonData.new(:name => "Callie",
                                                             :age => 12)),
                      :return => :object)

puts remy.key                                              # => server generated
puts client.get(bucket,remy.key)                           # => Jiak object
puts client.get(bucket,remy.key).data                      # => PersonData
puts client.get(bucket,remy.key).data.name                 # => remy

# Change data value and add a link to callie tagged as sister
remy.data.name = "Remy"
remy << JiakLink.new(bucket,callie.key,'sister')
client.store(remy)

# Show updated name
puts client.get(bucket,remy.key).data.name                 # => "Remy"

# Follow the sister link and show that it's callie
sisters = client.walk(bucket,remy.key,
                      QueryLink.new(bucket,'sister'),PersonData)
puts sisters[0].eql?(callie)                               # => true

# Clean-up
client.delete(bucket,remy.key)
client.delete(bucket,callie.key)
