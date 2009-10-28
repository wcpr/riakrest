require 'lib/riakrest'
include RiakRest

PersonData = JiakDataHash.create(:name,:age)
PersonData.keygen :name

class Person
  include JiakResource
  server      'http://localhost:8002/jiak'
  group       'people'
  data_class  PersonData
end

remy = Person.new(:name => 'remy', :age => 10)
remy.post
puts Person.get('remy').name                # => "remy"

remy.name = "Remy"
remy.update
puts Person.get('remy').name                # => "Remy"

callie = Person.new(:name => 'Callie', :age => 12).post
remy.link(callie,'sister').update

sisters = remy.walk(Person,'sister')
sisters[0].eql?(callie)                     # => true

remy.delete
callie.delete
