require File.join(File.dirname(__FILE__), 'buoy')
include Examples

buoys = BUOYS.map {|m| BuoyData.load(m)}.map {|b| Buoy.new(b)}.each {|m| m.post}

b0_srf = buoys[0].pov(BuoySurface)
b0_srf.temp_air = 15.0
b0_srf.update

buoys[0].refresh

class Region
  include JiakResource
  server  SERVER_URI
  group 'region'
  
  jattr_accessor :name
end

mbay = Region.new(:name => 'Monterey Bay')
mbay.post

buoys.each {|buoy| mbay.link(buoy,'buoy')}
mbay.update

moorings = mbay.query([Buoy,'buoy'])
moorings[0] == buoys[0]

# sst = buoys.map {|b| b.pov(BuoySST)}



