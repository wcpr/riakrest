require 'lib/riakrest'
include RiakRest

client = JiakClient.new("http://localhost:8002/jiak")
Person = JiakDataHash.create(:name,:age)
bucket = JiakBucket.create('person',Person)
client.set_schema(bucket)
remy = Person.create(:name => "remy", :age => 10)
jobj = JiakObject.create(:bucket => bucket, :data => remy)
key = client.store(jobj)
puts remy.name                           # => "remy"
puts client.get(bucket,key).data.name    # => "remy"
remy.name = "Remy"
client.store(jobj)
puts remy.name                           # => "Remy"
puts client.get(bucket,key).data.name    # => "remy"  ???

callie = Person.create(:name => "callie", :age => 12)
jobj = JiakObject.create(:bucket => bucket, :data => callie)
callie = client.store(jobj,{JiakClient::RETURN_BODY => true})
puts client.get(bucket,callie.key).data.name    # => "callie"
callie.data.name = "Callie"
callie = client.store(callie,{JiakClient::RETURN_BODY => true})
puts client.get(bucket,callie.key).data.name    # => "Callie"
