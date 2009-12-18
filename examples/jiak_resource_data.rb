require File.dirname(__FILE__) + '/example_helper.rb'
require 'date'

# JiakResource with a couple of attributes. Store birthdate as ordinal Date.
class Person
  include JiakResource
  server SERVER_URI
  attr_accessor :name, :birthdate
  attr_converter :birthdate => { :read => lambda{|value| Date.parse(value)} }
  keygen {name.downcase}

  # Calculate "human" age from birthdate
  def age
    now = DateTime.now
    age = now.year - birthdate.year
    if((now.month <  birthdate.month) or
       (now.month == birthdate.month and now.day < birthdate.day))
      age -= 1 
    end
    age
  end
end

# The birthdate attribute is a Date before and after post.
remy = Person.new(:name => 'Remy',:birthdate => Date.new(1999,06,26))
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>
puts remy.age                                   # => current age
remy.post
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>
puts remy.age                                   # => current age

remy.delete

# JSON payload from the HTTP request and response
#   {"name":"Remy","birthdate":"1999-06-26"}

class Person
  attr_converter(:birthdate => {
                   :write => lambda{|v| {:year => v.year, :yday => v.yday} },
                   :read  => lambda{|v| Date::ordinal(v['year'],v['yday'])}})
end

# The same code as previous yields the exact same results.
remy = Person.new(:name => 'Remy',:birthdate => Date.new(1999,06,26))
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>
puts remy.age                                   # => current age
remy.post
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>
puts remy.age                                   # => current age

remy.delete

# JSON payload from the HTTP request and response with ordinal Date structure
#   {"name":"Remy","birthdate":{"year":1999,"yday":177}}


# It is also possible to change the JSON processing of the Ruby Date class to
# achieve the same results as above. Given the following changes to the Date
# class, the Person class could be defined as before, but without any attribute
# converters.

# Instrument the Ruby Date class for round-trip JSON processing.
class Date
  def to_json(*args)
    { 'json_class' => self.class.name,
      'date' => to_s
    }.to_json(*args)
  end
  def self.json_create(hash)
    parse(hash['date'])
  end
end

class Person2
  include JiakResource
  server SERVER_URI
  attr_accessor :name, :birthdate
end

remy = Person2.new(:name => 'Remy',:birthdate => Date.new(1999,06,26))
remy.post
puts remy.birthdate.inspect                     # => #<Date: 1999-06-26 (etc.)>

# However, this is not optimal as the data stored in Riak now contains
# Ruby-secific information which may be undesirable to non-Ruby consumers of
# the data. For the code above, the JSON payload contains:
#
#   {"name":"Remy","birthdate":{"json_class":"Date","date":"1999-06-26"}}

