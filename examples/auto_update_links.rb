require File.dirname(__FILE__) + '/example_helper.rb'

# Simple resource used to show auto-updating of links.
class Person
  include JiakResource
  server         SERVER_URI
  attr_accessor :name, :age
  keygen { name.downcase }
  auto_post
end

# Convenience method for showing results
def num_links(rsrc,tag,expect)
  num = rsrc.query([Person,tag]).size
  puts "#{num} == #{expect}"
end

# Create resources. Auto-post posts the create.
remy = Person.new(:name => 'remy', :age => 10)
callie = Person.new(:name => 'Callie', :age => 12)

# Add links. Auto-post does not auto-update.
remy.link(callie,'sister')
num_links(remy,'sister',0)                           # => 0
remy.update
num_links(remy,'sister',1)                           # => 1
remy.remove_link(callie,'sister')
remy.update
num_links(remy,'sister',0)                           # => 0

# Turn on class level auto-update.
Person.auto_update true
remy.link(callie,'sibling')
num_links(remy,'sibling',1)                          # => 1
remy.remove_link(callie,'sibling')

# Instance level auto-update settings.
callie.auto_update = false
callie.link(remy,'sibling')
num_links(callie,'sibling',0)                        # => 0
callie.update
num_links(callie,'sibling',1)                        # => 1
callie.remove_link(remy,'sibling')

# bi_link create links in both directions.
Person.auto_update false
remy.auto_update = true
callie.auto_update = nil
remy.bi_link(callie,'sisters')
num_links(remy,'sisters',1)                          # => 1
num_links(callie,'sisters',0)                        # => 0
callie.update
num_links(callie,'sisters',1)                        # => 0

# Clean-up
remy.delete
callie.delete

