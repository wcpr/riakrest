require 'riakrest'
include RiakRest

class Dog
  include JiakResource
  server        'http://localhost:8002/jiak'
  jiak_accessor :name, :weight, :breed
  keygen { name.downcase }
end

class DogBreed
  include JiakResource
  server        'http://localhost:8002/jiak'
  jiak_accessor :name, :breed
end

class DogWeight
  include JiakResource
  server        'http://localhost:8002/jiak'
  jiak_accessor :name, :weight
end

Dog.pov
addie = Dog.new(:name => 'Adelaide', :weight => 45, :breed => 'heeler')
addie.post
puts addie.name                 # => "Adelaide"
puts addie.breed                # => "heeler"
puts addie.weight               # => 45

DogBreed.pov
addie = DogBreed.get('adelaide')
addie.breed = "Heeler"
addie.put

DogWeight.pov
addie = DogWeight.get('adelaide')
addie.weight = 47
addie.put

Dog.pov
addie = Dog.get('adelaide')
puts addie.name                 # => "Adelaide"
puts addie.breed                # => "Heeler"
puts addie.weight               # => 47

addie.delete
