require File.dirname(__FILE__) + '/example_helper.rb'

# Simple resource set to auto-manage instances. Auto-manage does both auto-post
# and auto-update.
class Person
  include JiakResource
  server         SERVER_URI
  attr_accessor :name, :age
  keygen { name }
  auto_manage
end

# Convenience method for showing results
def show_jiak_values
  rsrc = Person.get('remy')
  puts "name:#{rsrc.name}, age:#{rsrc.age}"
end


# Create resource. Auto-manage auto-posts the create.
remy = Person.new(:name => 'remy', :age => 10)
show_jiak_values                                       # => remy, 10

# Changes are auto-updated
remy.name = "Remy"
show_jiak_values                                       # => Remy, 10
remy.age = 12
show_jiak_values                                       # => Remy, 12

# Auto-update can be set at class and instance level
Person.auto_update false
remy.auto_update = true
remy.age = 10
show_jiak_values                                       # => Remy, 10

# Instance level setting overrides class level setting
Person.auto_update true
remy.auto_update = false
remy.age = 12
show_jiak_values                                       # => Remy, 10
remy.update
show_jiak_values                                       # => Remy, 12

# Due to class level interaction, set instance level to nil to get class level
remy.auto_update = nil
remy.age = 10
show_jiak_values                                       # => Remy, 10

# Clean-up
remy.delete


