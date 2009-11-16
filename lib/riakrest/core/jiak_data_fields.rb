module RiakRest
  # JiakDataFields provides a easy-to-create JiakData implementation.
  #
  # ===Usage
  # <code>
  #   Dog = JiakDataFields.create(:name,:weight)
  #
  #   addie = Dog.new(:name => "Adelaide", :weight => 45)
  #   addie.name                                           # => "Adeliade"
  #   addie.weight                                         # => 45
  #
  #   addie.weight = 47                                    # => 47
  # </code>
  #
  class JiakDataFields

    # :call-seq:
    #   JiakDataFields.create(:f1,...,fn)    -> JiakDataFields
    #   JiakDataFields.create([:f1,...,fn])  -> JiakDataFields
    #   JiakDataFields.create(schema)        -> JiakDataFields
    #
    # Creates a JiakDataFields class that can be used to create JiakData objects
    # containing the specified fields.
    def self.create(*args)
      Class.new do
        include JiakData

        if(args.size == 1)
          case args[0]
          when Symbol, Array
            jattr_accessor *args[0]
          when JiakSchema
            jattr_reader *args[0].read_mask
            jattr_writer *args[0].write_mask
            allow    *args[0].allowed_fields
            require  *args[0].required_fields
          end
        else
          jattr_accessor *args
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

      end
    end

  end
end
