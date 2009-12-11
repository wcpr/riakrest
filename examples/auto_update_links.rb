require File.dirname(__FILE__) + '/example_helper.rb'

# Simple resource used to show auto-updating of links.
class Person
  include JiakResource
  server         SERVER_URI
  attr_accessor :name, :age
  keygen { name.downcase }
  auto_post
end

# Convenience method for checking number of links
def check_num_links(rsrc,tag,expect)
  num = rsrc.query([Person,tag]).size
  puts " #{expect}? #{num == expect}"
end

# Create resources. (Auto-posted)
remy = Person.new(:name => 'remy', :age => 10)
callie = Person.new(:name => 'Callie', :age => 12)

# Add links. Class-level auto-post does not trigger auto-update.
remy.link(callie,'sister')
check_num_links(remy,'sister',0)                           # => true
remy.update
check_num_links(remy,'sister',1)                           # => true
remy.remove_link(callie,'sister')
remy.update
check_num_links(remy,'sister',0)                           # => true

# Turn on class level auto-update.
Person.auto_update true
remy.link(callie,'sibling')
check_num_links(remy,'sibling',1)                          # => true
remy.remove_link(callie,'sibling')

# Instance level auto-update settings.
callie.auto_update = false
callie.link(remy,'sibling')
check_num_links(callie,'sibling',0)                        # => true
callie.update
check_num_links(callie,'sibling',1)                        # => true
callie.remove_link(remy,'sibling')

# Another permutation of class and instance level auto-update settings.
Person.auto_update false
remy.auto_update = true
callie.auto_update = nil

# bi_link create links in both directions.
remy.bi_link(callie,'sisters')
check_num_links(remy,'sisters',1)                          # => true
check_num_links(callie,'sisters',0)                        # => true
callie.update
check_num_links(callie,'sisters',1)                        # => true

# Clean-up
remy.delete
callie.delete

