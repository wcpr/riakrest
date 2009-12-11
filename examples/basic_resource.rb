require File.dirname(__FILE__) + '/example_helper.rb'

# Simple JiakResource with a couple of attributes
class Person
  include JiakResource
  server SERVER_URI
  attr_accessor :name, :age
  keygen {name.downcase}
end

# Convenience method for showing results
def show_jiak_values
  rsrc = Person.get('remy')
  puts "name:#{rsrc.name}, age:#{rsrc.age}"
end

# Created and store a resource.
remy = Person.new(:name => 'Remy',:age => 10)
puts "name:#{remy.name}, age:#{remy.age}"     # => Remy, 10
remy.post
show_jiak_values                              # => Remy, 10

# Change and store
remy.age = 11
remy.put
show_jiak_values                              # => Remy, 11

# Create another resource
callie = Person.new(:name => 'Callie', :age => 13)
callie.post

# Add a link from remy to callie tagged as 'sister'
remy.link(callie,'sister')
remy.put

# Retrieve sister via link
sisters = remy.query([Person,'sister'])
puts sisters.include?(callie)                 # => true
puts sisters.size                             # => 1
puts sisters[0].name                          # => "Callie"

# Clean-up
remy.delete
callie.delete
