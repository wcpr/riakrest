# buoy.rb contains resource and POV class declarations
require File.join(File.dirname(__FILE__), 'buoy')

# Load buoy data
buoy0,buoy1,buoy2 = 
  BUOYS.map {|m| BuoyData.load(m)}.map {|b| Buoy.new(b)}.each {|m| m.post}

# Loaded data for Buoy, BuoySurface, and BuoySST
buoy0_srf = buoy0.pov(BuoySurface)
buoy0_sst = buoy0.pov(BuoySST)
puts "Loaded data"
show_data(buoy0)
show_data(buoy0_srf)
show_data(buoy0_sst)

# Change SST via BuoySurface POV
buoy0_srf.temp_0 = 14.99
buoy0_srf.update
buoy0.refresh
buoy0_sst.refresh
puts
puts "SST set to 14.99 via BuoySurface POV"
show_data(buoy0)
show_data(buoy0_srf)
show_data(buoy0_sst)

# Create a region and link the 3 buoys
mbay = Region.new(:name => 'Monterey Bay')
mbay.post
[buoy0,buoy1,buoy2].each {|buoy| mbay.link(buoy,'buoy')}
mbay.update

# Get all MBay buoys via query as both Buoy and BuoySST
buoys = mbay.query([Buoy,'buoy'])
sst = mbay.query([BuoySST,'buoy'])
puts
puts "Check SST of M0 buoy as both Buoy and BuoySST POV"
m0_buoy = buoys.find {|buoy| buoy.name.eql?('M0')}
m0_sst  =   sst.find {|buoy| buoy.name.eql?('M0')}
show_data(m0_buoy)
show_data(m0_sst)
puts " #{m0_buoy.temp_0 == m0_sst.temp_0}"                   # => true

# Clean-up
[buoy0,buoy1,buoy2,mbay].each {|rsrc| rsrc.delete}

