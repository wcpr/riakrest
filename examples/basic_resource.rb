require 'riakrest'
include RiakRest

PersonData = JiakDataHash.create(:name,:age)
PersonData.keygen :name

class Person
  include JiakResource
  server      'http://localhost:8002/jiak'
  group       'people'
  data_class  PersonData
  auto_post   true
  auto_update true
end

remy = Person.new(:name => 'Remy',:age => 10) #            (auto-post)
puts remy.name                                # => "Remy"

puts Person.get('Remy').name                  # => "Remy"  (from Jiak server)
puts Person.get('Remy').age                   # => 10      (from Jiak server)

remy.age = 11                                 #            (auto-update)
puts Person.get('Remy').age                   # => 11      (from Jiak server)

callie = Person.new(:name => 'Callie', :age => 13)
remy.link(callie,'sister')

sisters = remy.query(Person,'sister')
puts sisters[0].eql?(callie)                  # => true

remy.delete
callie.delete
