require File.dirname(__FILE__) + '/example_helper.rb'
require 'date'

# JiakData class with a couple of attributes, one with conversion
class DateData
  include JiakData
  attr_accessor :name, :date

  attr_converter :date => { :read => lambda{|value| Date.parse(value)} }
end

client = JiakClient.new(SERVER_URI)
bucket = JiakBucket.new('date data',DateData)

# Leap data date is a Data object
leap_2008 = DateData.new(:name => "Leap 2008", 
                         :date => Date.new(2008,02,29))
leap_obj = client.store(JiakObject.new(:bucket => bucket,
                                       :data => leap_2008),
                        :return => :object)
puts leap_obj.data.date.inspect                 # => #<Date: 2008-02-29 (etc.)>

# Clean-up stored object
client.delete(bucket,leap_obj.key)


# Alter DateData to store ordinal Date
class DateData
  attr_converter(:date => {
                   :write => lambda {|v| { :year => v.year, :yday => v.yday} },
                   :read  => lambda {|v| Date::ordinal(v['year'],v['yday'])} } )
end
leap_obj = client.store(JiakObject.new(:bucket => bucket,
                                       :data => leap_2008),
                        :return => :object)
puts leap_obj.data.date.inspect                 # => #<Date: 2008-02-29 (etc.)>

# JSON payload
#   {"name":"Leap 2008","date":{"year":2008,"yday":60}}

# Clean-up stored object
client.delete(bucket,leap_obj.key)


# It is also possible to change the JSON processing of the Ruby Date class to
# achieve the same results as above. Given the following changes to the Date
# class, the DateData class could be defined as before, but without any
# attribute converters.

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

class DateData2
  include JiakData
  attr_accessor :name, :date
end

bucket = JiakBucket.new('date data',DateData2)

leap_2008 = DateData2.new(:name => "Leap 2008", 
                          :date => Date.new(2008,02,29))
leap_obj = client.store(JiakObject.new(:bucket => bucket,
                                       :data => leap_2008),
                        :return => :object)
puts leap_obj.data.date.inspect                 # => #<Date: 2008-02-29 (etc.)>

# However, this is not optimal as the data stored in Riak now contains
# Ruby-secific information which may be undesirable to non-Ruby consumers of
# the data. For the code above, the JSON payload contains:
#
#   {"name":"Leap 2008","date":{"json_class":"Date","date":"2008-02-29"}}

# Clean-up stored object
client.delete(bucket,leap_obj.key)
