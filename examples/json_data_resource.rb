require 'date'
class DogData  # :nodoc:
  include JiakData

  allowed :name, :birthdate, :weight, :breed
  writable :name, :birthdate, :weight
  readable :name, :birthdate, :weight

  def initialize(hsh)
    hsh.each {|key,val| send("#{key}=",val)}
  end

  def self.create(hsh)
    new(hsh)
  end

  def self.jiak_create(jiak)
    jiak['birthdate'] = Date.parse(jiak['birthdate']) if jiak['birthdate']    
    new(jiak)
  end

  def for_jiak
    self.class.write_mask.inject({}) do |build,field|
      val = send("#{field}")
      build[field] = val   unless val.nil?
      build
    end
  end

  def keygen
    @name
  end
end
