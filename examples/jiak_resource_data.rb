require File.dirname(__FILE__) + '/example_helper.rb'
require 'date'

# JiakResource with a couple of attributes, one of which requires conversion
class Person
  include JiakResource
  server SERVER_URI
  attr_accessor :name, :birthdate
  convert :birthdate => lambda{|value| Date.parse(value)}
  keygen {name.downcase}

  def age
    now = DateTime.now
    age = now.year - birthdate.year
    age -= 1 if(now.yday < birthdate.yday)
    age
  end
end

# Create and post resource, showing birthdate is a Date before and after post.
remy = Person.new(:name => 'Remy',:birthdate => Date.new(1999,06,26))
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>
puts remy.age                                   # => current age
remy.post
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>
puts remy.age                                   # => current age

remy.delete

