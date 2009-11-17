require 'riakrest'
include RiakRest

# CxINC Example doesn't do anything useful yet

require 'date'
class DogData  # :nodoc:
  include JiakData

  allowed   :name, :birthdate, :weight, :breed
  readwrite :name, :birthdate, :weight

  keygen { name.downcase }

  def self.jiak_create(jiak)
    jiak['birthdate'] = Date.parse(jiak['birthdate']) if jiak['birthdate']    
    new(jiak)
  end
end
