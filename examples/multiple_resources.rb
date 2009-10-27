
require 'lib/riakrest'
include RiakRest

DogData = JiakDataHash.create(:name, :weight, :breed)
class DogData
  def keygen
    @name
  end
end
class Dog
  include JiakResource
  server   'http://localhost:8002/jiak'
  resource :name => 'dogs', :data_class => DogData
end

DogBreedData = JiakDataHash.create(DogData.schema.allowed_fields)
DogBreedData.readable :name, :breed
DogBreedData.writable :breed
class DogBreed
  include JiakResource
  server   Dog.jiak.uri
  resource :name => Dog.jiak.name,
           :data_class => DogBreedData
end

DogWeightData = JiakDataHash.create(DogData.schema.allowed_fields)
DogWeightData.readable :name, :weight
DogWeightData.writable :weight
class DogWeight
  include JiakResource
  server   Dog.jiak.uri
  resource :name => Dog.jiak.name,
           :data_class => DogWeightData
end

Dog.activate
addie = Dog.new(:name => 'adelaide', :weight => 45, :breed => 'heeler')
addie.post
puts addie.name                 # => "adelaide"
puts addie.breed                # => "heeler"
puts addie.weight               # => 45

DogBreed.activate
addie = DogBreed.get('adelaide')
addie.breed = "Heeler"
addie.put

DogWeight.activate
addie = DogWeight.get('adelaide')
addie.weight = 47
addie.put

Dog.activate
addie = Dog.get('adelaide')
puts addie.name                 # => "adelaide"
puts addie.breed                # => "Heeler"
puts addie.weight               # => 47

