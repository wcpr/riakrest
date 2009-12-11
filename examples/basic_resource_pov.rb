require File.dirname(__FILE__) + '/example_helper.rb'

class AB
  include JiakResource
  server SERVER_URI
  group  "test"
  attr_accessor :a, :b
  keygen { "k#{a}" }
end

class A
  include JiakResourcePOV
  resource AB
  attr_accessor :a
end

class B
  include JiakResourcePOV
  resource AB
  attr_accessor :b
end

# Store data using AB
puts "POST ab.a=1, ab.b=2"
ab = AB.new(:a => 1, :b => 2)
ab.post

# Get POVs using two different mechanisms.
a = ab.pov(A)
b = B.get('k1')
puts "a=#{ab.a}, b=#{ab.b}"                                   # => a=1, b=2
puts "ab.a and a.a equal   1? #{ab.a == 1 && ab.a == a.a}"    # =>   1? true
puts "ab.b and b.b equal   2? #{ab.b == 2 && ab.b == b.b}"    # =>   2? true

# Update data using AB
puts "\nPUT ab.a=11"
ab.a = 11
ab.update
a.refresh
b.refresh
puts "a = #{ab.a}, b = #{ab.b}"                               # => a=11, b=2
puts "ab.a and a.a equal  11? #{ab.a == 11 && ab.a == a.a}"   # =>  11? true
puts "ab.b and b.b equal   2? #{ab.b == 2  && ab.b == b.b}"   # =>   2? true

# Update data using A
puts "\nPUT a.a=111"
a.a = 111
a.update
ab.refresh
b.refresh
puts "a = #{ab.a}, b = #{ab.b}"                               # => a=111, b=2
puts "ab.a and a.a equal 111? #{ab.a == 111 && ab.a == a.a}"  # => 111? true
puts "ab.b and b.b equal   2? #{ab.b == 2   && ab.b == b.b}"  # =>   2? true

# Update data using B
puts "\nPUT b.b=22"
b.b = 22
b.update
ab.refresh
a.refresh
puts "a = #{ab.a}, b = #{ab.b}"                               # => a=111, b=22
puts "ab.a and a.a equal 111? #{ab.a == 111 && ab.a == a.a}"  # => 111? true
puts "ab.b and b.b equal  22? #{ab.b == 22  && ab.b == b.b}"  # =>  22? true

ab.delete
