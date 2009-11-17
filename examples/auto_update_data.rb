require 'riakrest'
include RiakRest

class People
  include JiakResource
  server         'http://localhost:8002/jiak'
  jattr_accessor :name, :age
  keygen { name }
  auto_manage
end

remy = People.new(:name => 'remy', :age => 10)
puts People.get('remy').name                      # => "remy"

remy.name = "Remy"
puts People.get('remy').name                      # => "Remy"
remy.age = 12
puts People.get('remy').age                       # => 12

People.auto_update false
remy.auto_update = true
puts People.get('remy').age                       # => 12
remy.age = 10
puts People.get('remy').age                       # => 10

People.auto_update true
remy.auto_update = false
remy.age = 12
puts People.get('remy').age                       # => 10
remy.update
puts People.get('remy').age                       # => 12

remy.auto_update = nil
remy.age = 10
puts People.get('remy').age                       # => 10

remy.delete


