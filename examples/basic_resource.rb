require File.dirname(__FILE__) + '/example_helper.rb'

# Simple resource.
class Person
  include JiakResource
  server SERVER_URI
  attr_accessor :name, :age
  keygen {name.downcase}
  auto_manage
end

# Convenience method for showing results
def show_jiak_values
  rsrc = Person.get('remy')
  puts "name:#{rsrc.name}, age:#{rsrc.age}"
end

# Created resource is auto-posted
remy = Person.new(:name => 'Remy',:age => 10)
show_jiak_values                                 # => Remy, 10
puts "name:#{remy.name}, age:#{remy.age}"        # => Remy, 10

# Change is auto-updated
remy.age = 11
show_jiak_values                                 # => Remy, 11

# Created resource auto-posted and added link auto-updated
callie = Person.new(:name => 'Callie', :age => 13)
remy.link(callie,'sister')
sisters = remy.query([Person,'sister'])
puts sisters[0].eql?(callie)                     # => true

# Clean-up
remy.delete
callie.delete
