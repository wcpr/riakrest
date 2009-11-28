require File.dirname(__FILE__) + '/example_helper.rb'

class PeopleData
  include JiakData
  jattr_accessor :name, :age
end

client = JiakClient.new(SERVER_URI)
bucket = JiakBucket.new('people',PeopleData)
client.set_schema(bucket)

remy = client.store(JiakObject.new(:bucket => bucket,
                                    :data => PeopleData.new(:name => "remy",
                                                            :age => 10)),
                    :return => :object)
callie = client.store(JiakObject.new(:bucket => bucket,
                                     :data => PeopleData.new(:name => "Callie",
                                                             :age => 12)),
                      :return => :object)

puts client.get(bucket,remy.key).data.name                         # => "remy"

remy.data.name = "Remy"
remy << JiakLink.new(bucket,callie.key,'sister')
client.store(remy)

puts client.get(bucket,remy.key).data.name                         # => "Remy"

sisters = client.walk(bucket,remy.key,
                      QueryLink.new(bucket,'sister'),PeopleData)
puts sisters[0].eql?(callie)                                       # => true

client.delete(bucket,remy.key)
client.delete(bucket,callie.key)
