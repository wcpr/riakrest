require 'lib/riakrest'
include RiakRest

PersonData = JiakDataHash.create(:name,:age)
PersonData.keygen :name

class Person
  include JiakResource

  server       'http://localhost:8002/jiak'
  group        'people'
  data_class   PersonData
  auto_post    true
  auto_update  true
end

remy = Person.new(:name => 'remy', :age => 10)
puts Person.get('remy').name                # => "remy"

remy.name = "Remy"
puts Person.get('remy').name                # => "Remy"
remy.age = 12
puts Person.get('remy').age                 # => 12

Person.auto_update false
remy.auto_update = true
puts Person.get('remy').age                 # => 12
remy.age = 10
puts Person.get('remy').age                 # => 10

Person.auto_update true
remy.auto_update = false
remy.age = 12
puts Person.get('remy').age                 # => 10
remy.update
puts Person.get('remy').age                 # => 12

remy.auto_update = nil
remy.age = 10
puts Person.get('remy').age                 # => 10

remy.delete


