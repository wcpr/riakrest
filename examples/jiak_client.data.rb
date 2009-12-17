require File.dirname(__FILE__) + '/example_helper.rb'
require 'date'

# JiakData class with a couple of attributes, one of which requires conversion
class DateData
  include JiakData
  attr_accessor :name, :date
  convert :date => lambda{|value| Date.parse(value)}
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


# It is also possible to use Ruby JSON processing to achieve a similar result;
# however, this is not optimal as the stored Riak data value contains
# Ruby-secific information which may be undesirable to non-Ruby consumers of
# that data.

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

leap_2012 = DateData2.new(:name => "Leap 2012", 
                          :date => Date.new(2012,02,29))
leap_obj = client.store(JiakObject.new(:bucket => bucket,
                                       :data => leap_2012),
                        :return => :object)
puts leap_obj.data.date.inspect                 # => #<Date: 2012-02-29 (etc.)>

# JSON payload: 
#  leap_2008 : {"name":"leap","date":"2008-02-29"}
#  leap_2012 : {"name":"leap","date":{"json_class":"Date","date":"2012-02-29"}}

# Clean-up stored object
client.delete(bucket,leap_obj.key)
