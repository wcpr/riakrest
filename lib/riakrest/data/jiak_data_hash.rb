module RiakRest
  # A simple JiakData created from a list of fields and initialized by a hash
  # with those fields as keys. Creates read and write accessors for each
  # field. Values can also be accessed via [] and []=. Other hash sematics are
  # not provided. The method JiakDataHash#to_hash does, however, return a hash
  # of the data fields and values.
  #
  # ===Usage
  # <code>
  #   Dog = JiakDataHash.create(:name,:weight)
  #   Dog.keygen :name
  #
  #   addie = Dog.new(:name => "Adelaide", :weight => 45)
  #   addie.name                                           # => "Adeliade"
  #   addie.weight                                         # => 45
  #
  #   addie.weight = 47                                    # => 47
  # </code>
  #
  class JiakDataHash

    # :call-seq:
    #   JiakDataHash.create(:f1,...,fn)    -> JiakDataHash
    #   JiakDataHash.create([:f1,...,fn])  -> JiakDataHash
    #   JiakDataHash.create(schema)        -> JiakDataHash
    #
    # Creates a JiakDataHash class that can be used to create JiakData objects
    # containing the specified fields.
    def self.create(*args)
      Class.new do
        include JiakData

        if(args.size == 1)
          case args[0]
          when Symbol, Array
            allowed *args[0]
          when JiakSchema
            allowed  *args[0].allowed_fields
            required *args[0].required_fields
            readable *args[0].read_mask
            writable *args[0].write_mask
          end
        else
          allowed *args
        end

        # :call-seq:
        #   DataClass.keygen(*fields)
        #
        # The key generation for the data class will be a concatenation of the
        # to_s result of calling each of the listed data class fields.
        def self.keygen(*fields)
          define_method(:keygen) do
            fields.inject("") {|key,field| key += send("#{field}").to_s}
          end
        end

        # :call-seq:
        #   data.new({})  -> JiakDataHash
        #
        # Create an instance of the user-defined JiakDataHash using the provide
        # hash as initial values.
        def initialize(hsh={})
          hsh.each {|key,value| send("#{key}=",value)}
        end
        
        # :call-seq:
        #   data.jiak_create(jiak)  ->  JiakDataHash
        #
        # Used by RiakRest to create an instance of the user-defined data class
        # from the values returned by the Jiak server.
        def self.jiak_create(jiak)
          new(jiak)
        end

        # :call-seq:
        #   data[field] -> value
        #
        # Get the value of a field.
        #
        # Returns <code>nil</code> if <code>field</code> was not declared for
        # this class. <code>field</code> can be in either string or symbol
        # form.
        def [](key)
          send("#{key}") rescue nil
        end

        # :call-seq:
        #   data[field] = value
        #
        # Set the value of a field.
        #
        # Returns the value set, or <code>nil</code> if <code>field</code> was
        # not declared for this class.
        def []=(key,value)
          send("#{key}=",value)  rescue nil
        end

        # :call-seq:
        #   data.for_jiak  -> hash
        #
        # Return a hash of the writable fields and their values. Used by
        # RiakRest to prepare the data for transport to the Jiak server.
        def for_jiak
          self.class.schema.write_mask.inject({}) do |build,field|
            val = send("#{field}")
            build[field] = val  unless val.nil?
            build
          end
        end
        
        # :call-seq:
        #   data.to_hash
        #
        # Return a hash of the allowed fields and their values.
        def to_hash
          self.class.schema.allowed_fields.inject({}) do |build,field|
            val = send("#{field}")
            build[field] = val
            build
          end
        end


        # call-seq:
        #    jiak_data == other -> true or false
        #
        # Equality -- Two JiakDataHash objects are equal if they contain the
        # same values for all attributes.
        def ==(other)
          self.class.schema.allowed_fields.reduce(true) do |same,field|
            same && (other.send("#{field}") == (send("#{field}")))
          end
        end

        # call-seq:
        #    data.eql?(other) -> true or false
        #
        # Returns <code>true</code> if <code>other</code> is a JiakObject with
        # the same the same attribute values for all allowed fields.
        def eql?(other)
          other.is_a?(self.class) &&
            self.class.schema.allowed_fields.reduce(true) do |same,field|
            same && other.send("#{field}").eql?(send("#{field}"))
          end
        end

        def hash   # :nodoc:
          self.class.schema.allowed_fields.inject(0) do |hsh,field|
            hsh += send("#{field}").hash
          end
        end

      end
    end

  end
end
