require 'riakrest'
include RiakRest

class Person
  include JiakResource
  server   'http://localhost:8002/jiak'
  resource :name => 'person',
           :data_class => JiakDataHash.create(:name,:age)
end

remy = Person.create(:name => 'remy', :age => 10)
remy.store

puts remy.name                           # => "remy"
puts Person.get(remy.jiak.key).name      # => "remy"

remy.name = "Remy"
remy.update

puts remy.name                           # => "Remy"
puts Person.get(remy.jiak.key).name      # => "Remy"

remy.delete
