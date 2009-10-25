require 'lib/riakrest'
include RiakRest

class Person
  include JiakResource
  server   'http://localhost:8002/jiak'
  resource :name => 'person',
           :data_class => JiakDataHash.create(:name,:age)
end

remy = Person.new(:name => 'remy', :age => 10)
remy.post

puts remy.name                           # => "remy"
puts Person.get(remy.jiak.key).name      # => "remy"

remy.name = "Remy"
remy.put

puts remy.name                           # => "Remy"
puts Person.get(remy.jiak.key).name      # => "Remy"

remy.delete
