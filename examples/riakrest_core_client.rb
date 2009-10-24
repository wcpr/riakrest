require 'lib/riakrest'
include RiakRest

client = JiakClient.new("http://localhost:8002/jiak")
Person = JiakDataHash.create(:name,:age)
bucket = JiakBucket.new('person',Person)
client.set_schema(bucket)
remy = Person.new(:name => "remy", :age => 10)
jobj = JiakObject.new(:bucket => bucket, :data => remy)
key = client.store(jobj)
puts remy.name                           # => "remy"
puts client.get(bucket,key).data.name    # => "remy"
remy.name = "Remy"
client.store(jobj)
puts remy.name                           # => "Remy"
puts client.get(bucket,key).data.name    # => "remy"  ???

callie = Person.new(:name => "callie", :age => 12)
jobj = JiakObject.new(:bucket => bucket, :data => callie)
jobj = client.store(jobj,{:object => true})
callie = jobj.data
callie.name                                   # => "callie"
puts client.get(bucket,jobj.key).data.name    # => "callie"

callie.name = "Callie"                        # => "Callie"
jobj = client.store(jobj,{:object => true})
puts client.get(bucket,jobj.key).data.name    # => "Callie"

client.delete(bucket,jobj.key)



require 'lib/riakrest'
include RiakRest

Person = JiakDataHash.create(:name,:age)
remy = Person.new(:name => "remy", :age => 10)

client = JiakClient.new("http://localhost:8002/jiak")
bucket = JiakBucket.new('person',Person)
client.set_schema(bucket)
jobj = JiakObject.new(:bucket => bucket, :data => remy)
key = client.store(jobj)

remy.name                                # => "remy"
remy.name = "Remy"                       # => "Remy"
remy = client.get(bucket,key).data
remy.name                                # => "remy" (get overwrote local change)
client.delete(bucket,key)
