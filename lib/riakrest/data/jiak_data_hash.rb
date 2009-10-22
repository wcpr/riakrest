module RiakRest
  # A simple JiakData initialized by a hash. Creates accessors for each hash
  # key. Values can also be accessed via [] and []=. Other hash sematics are
  # not provided. To operate on the data as a hash, use JiakDataHash#to_hash to
  # get a hash of the data values.
  #
  # ===Usage
  # <code>
  #   require 'date'
  #   Dog = JiakDataHash.create(:name,:weight)
  #   addie = Dog.create(:name => "Adelaide",
  #                      :weight => 45)
  #
  #   addie.name                                       # -> "Adeliade"
  #   addie.weight                                     # -> 45
  # </code>
  #
  class JiakDataHash

    private_class_method :new   # :nodoc:

    # :call-seq:
    #   JiakDataHash.create :field_1, :field_2, ..., field_n  -> JiakDataHash
    #
    # Creates a JiakDataHash class that can be used to create JiakData objects
    # containing the specified fields.
    def self.create(*fields)
      Class.new do
        include JiakData

        allowed *fields

        def initialize(hsh)
          hsh.each {|key,value| send("#{key}=",value)}
        end

        def self.create(hsh={})
          new(hsh)
        end

        def self.jiak_create(jiak)
          new(jiak)
        end

        def [](key)
          send("#{key}")
        end

        def []=(key,value)
          send("#{key}=",value)
        end

        def for_jiak
          self.class.write_mask.inject({}) do |build,field|
            val = send("#{field}")
            build[field] = val  #  unless val.nil?
            build
          end
        end

        def to_hash
          for_jiak
        end

        def eql?(other)
          unless other.is_a?(self.class)
            raise JiakDataException, "eql? requires another #{self.class}"
          end
          begin
            self.class.allowed_fields.reduce(true) do |same,field|
              same && other.send("#{field}").eql?(send("#{field}"))
            end
          rescue
            false
          end
        end

        def ==(other)
          unless other.is_a?(self.class)
            raise JiakDataException, "== requires another #{self.class}"
          end
          begin
            self.class.allowed_fields.reduce(true) do |same,field|
              same && other.send("#{field}") == (send("#{field}"))
            end
          rescue
            false
          end
        end

      end
    end

  end
end
