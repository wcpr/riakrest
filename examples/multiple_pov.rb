require 'riakrest'
include RiakRest

DogData = JiakDataHash.create(:name,:weight,:breed)
DogData.keygen :name
class Dog
  include JiakResource
  server      'http://localhost:8002/jiak'
  group       'dogs'
  data_class  DogData
end

DogBreedData = JiakDataHash.create(DogData.schema)
DogBreedData.readwrite :name, :breed
DogBreed = Dog.copy(:data_class => DogBreedData)

DogWeightData = JiakDataHash.create(DogData.schema)
DogWeightData.readwrite :name, :weight
DogWeight = Dog.copy(:data_class => DogWeightData)

Dog.pov
addie = Dog.new(:name => 'adelaide', :weight => 45, :breed => 'heeler')
addie.post
puts addie.name                 # => "adelaide"
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
puts addie.name                 # => "adelaide"
puts addie.breed                # => "Heeler"
puts addie.weight               # => 47

addie.delete
