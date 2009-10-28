require 'lib/riakrest'
include RiakRest

Person = JiakDataHash.create(:name,:age)

client = JiakClient.new("http://localhost:8002/jiak")
bucket = JiakBucket.new('people',Person)
client.set_schema(bucket)

remy = client.store(JiakObject.new(:bucket => bucket,
                                    :data => Person.new(:name => "remy",
                                                        :age => 10)),
                     :object => true)
puts client.get(bucket,remy.key).data.name         # => "remy"

remy.data.name                                     # => "remy"
remy.data.name = "Remy"
client.store(remy)
puts client.get(bucket,remy.key).data.name         # => "Remy"


callie = client.store(JiakObject.new(:bucket => bucket,
                                     :data => Person.new(:name => "Callie",
                                                         :age => 12)),
                      :object => true)
remy   << JiakLink.new(bucket,callie.key,'sister')
client.store(remy)

sisters = client.walk(bucket,remy.key,QueryLink.new(bucket,'sister'),Person)
sisters[0].eql?(callie)                            # => true

client.delete(bucket,remy.key)
client.delete(bucket,callie.key)
