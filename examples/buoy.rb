require File.join(File.dirname(__FILE__), 'example_helper.rb')

# Primary resource declares server URI, and optional group and keygen, along
# with full complement of attributes.
class Buoy
  include JiakResource

  server SERVER_URI
  group "buoy"
  keygen { name }

  attr_accessor :name
  attr_accessor :lat, :lon
  attr_accessor :wind_u, :wind_v, :temp_air
  attr_accessor :temp_0,  :salt_0
  attr_accessor :temp_10, :salt_10
  attr_accessor :temp_20, :salt_20
end

# POVs declares an existing JiakResource and a subset of attributes, which can
# be read, write, or both.
class BuoySurface
  include JiakResourcePOV
  resource Buoy

  attr_reader   :name
  attr_reader   :lat, :lon
  attr_accessor :wind_u, :wind_v, :temp_air
  attr_accessor :temp_0, :salt_0
end

class BuoyChain
  include JiakResourcePOV
  resource Buoy

  attr_accessor :temp_0,  :salt_0
  attr_accessor :temp_10, :salt_10
  attr_accessor :temp_20, :salt_20
end

class BuoyWind
  include JiakResourcePOV
  resource Buoy

  attr_reader   :name
  attr_accessor :wind_u, :wind_v
end

class BuoySST
  include JiakResourcePOV
  resource Buoy

  attr_reader :name, :temp_0
end

# A simple resource for a region of buoys
class Region
  include JiakResource
  server  SERVER_URI
  group 'region'
  
  attr_accessor :name
end


# Some data and a loading mechanism
M0 = ["M0",[36.83, -121.90], [2.51, 3.12],
      [15.04, 14.98, 14.85, 13.22], [33.34, 33.38, 33.84]]
M1 = ["M1",[36.75, -122.03], [3.35, 2.42],
      [15.54, 14.43, 14.41, 14.01], [33.37, 33.43, 33.41]]
M2 = ["M2",[36.70, -122.39], [0.51, 0.44],
      [14.24, 14.03, 13.80, 13.82], [33.20, 33.11, 33.03]]

BUOYS = [M0,M1,M2]

class BuoyData
  def self.load(m)
    b = {}
    b[:name] = m[0]
    b[:lat],b[:lon] = m[1][0],m[1][1]
    b[:wind_u],b[:wind_v] = m[2][0],m[2][1]
    b[:temp_air],b[:temp_0],b[:temp_10],b[:temp_20] = 
      m[3][0],m[3][1],m[3][2],m[3][3]
    b[:salt_0],b[:salt_10],b[:salt_20] = m[4][0],m[4][1],m[4][2]
    b
  end

end

def show_data(rsrc)
  if(rsrc.class.include?(JiakResourcePOV))
    read_mask = rsrc.class.jiak.read_mask.split(',')
  else
    read_mask = rsrc.class.jiak.bucket.schema.read_mask
  end
  arr = read_mask.map do |field|
    val = rsrc.send(field)
    "#{field.to_s}= #{val}"
  end
  puts " #{rsrc.class}: #{arr.join(',')}"
end

