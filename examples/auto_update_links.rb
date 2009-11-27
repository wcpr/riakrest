require File.dirname(__FILE__) + '/example_helper.rb'

class People
  include JiakResource
  server         'http://localhost:8002/jiak'
  jattr_accessor :name, :age
  keygen { name.downcase }
  auto_post
end

remy = People.new(:name => 'remy', :age => 10)
callie = People.new(:name => 'Callie', :age => 12)

remy.link(callie,'sister')
puts remy.query(People,'sister').size              # => 0
remy.update
puts remy.query(People,'sister').size              # => 1
remy.remove_link(callie,'sister')

People.auto_update true
remy.link(callie,'sibling')
puts remy.query(People,'sibling').size             # => 1
remy.remove_link(callie,'sibling')

callie.auto_update = false
callie.link(remy,'sibling')
puts callie.query(People,'sibling').size           # => 0
callie.update
puts callie.query(People,'sibling').size           # => 1
callie.remove_link(remy,'sibling')

People.auto_update false
remy.auto_update = true
callie.auto_update = nil
remy.bi_link(callie,'sisters')
puts remy.query(People,'sisters').size             # => 1
puts callie.query(People,'sisters').size           # => 0
callie.update
puts callie.query(People,'sisters').size           # => 1

remy.delete
callie.delete

