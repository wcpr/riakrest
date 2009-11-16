require 'riakrest'
include RiakRest

class People
  include JiakResource
  server 'http://localhost:8002/jiak'
  jattr_accessor :name, :age
  keygen {name.downcase}
  auto_manage
end

remy = People.new(:name => 'Remy',:age => 10)    #            (auto-post)
puts remy.name                                   # => "Remy"

puts People.get('remy').name                     # => "Remy"  (from Jiak server)
puts People.get('remy').age                      # => 10      (from Jiak server)

remy.age = 11                                    #            (auto-update)
puts People.get('remy').age                      # => 11      (from Jiak server)

callie = People.new(:name => 'Callie', :age => 13)
remy.link(callie,'sister')

sisters = remy.query(People,'sister')
puts sisters[0].eql?(callie)                     # => true

remy.delete
callie.delete
