require 'riakrest'
include RiakRest

PersonData = JiakDataHash.create(:name,:age)
PersonData.keygen :name

class Person
  include JiakResource

  server       'http://localhost:8002/jiak'
  group        'people'
  data_class   PersonData
  auto_post    true
end

remy = Person.new(:name => 'remy', :age => 10)
callie = Person.new(:name => 'Callie', :age => 12)

remy.link(callie,'sister')
puts remy.query(Person,'sister').size        # => 0
remy.update
puts remy.query(Person,'sister').size        # => 1
remy.remove_link(callie,'sister')

Person.auto_update true
remy.link(callie,'sibling')
puts remy.query(Person,'sibling').size       # => 1
remy.remove_link(callie,'sibling')

callie.auto_update = false
callie.link(remy,'sibling')
puts callie.query(Person,'sibling').size     # => 0
callie.update
puts callie.query(Person,'sibling').size     # => 1
callie.remove_link(remy,'sibling')

Person.auto_update false
remy.auto_update = true
callie.auto_update = nil
remy.bi_link(callie,'sisters')
puts remy.query(Person,'sisters').size       # => 1
puts callie.query(Person,'sisters').size     # => 0
callie.update
puts callie.query(Person,'sisters').size     # => 1

remy.delete
callie.delete

