require 'riakrest'
include RiakRest

class People
  include JiakData
  jattr_accessor :name, :age
end

client = JiakClient.new("http://localhost:8002/jiak")
bucket = JiakBucket.new('people',People)
client.set_schema(bucket)

remy = client.store(JiakObject.new(:bucket => bucket,
                                    :data => People.new(:name => "remy",
                                                        :age => 10)),
                     :return => :object)
callie = client.store(JiakObject.new(:bucket => bucket,
                                     :data => People.new(:name => "Callie",
                                                         :age => 12)),
                      :return => :object)

puts client.get(bucket,remy.key).data.name         # => "remy"

remy.data.name = "Remy"
remy << JiakLink.new(bucket,callie.key,'sister')
client.store(remy)

puts client.get(bucket,remy.key).data.name         # => "Remy"

sisters = client.walk(bucket,remy.key,QueryLink.new(bucket,'sister'),People)
puts sisters[0].eql?(callie)                       # => true

client.delete(bucket,remy.key)
client.delete(bucket,callie.key)
