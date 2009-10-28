module RiakRest

  # Schema for data objects placed in a Riak bucket. Riak performs basic checks
  # for storing and retrieving data objects in a bucket by ensuring:
  #
  # * Only allowed fields are used.
  # * Required fields are included.
  # * Only writable fields are stored.
  # * Only readable fields are retrieved.
  #
  # The schema for a bucket can be changed dynamically so this doesn't lock
  # storage of data objects to a static structure. To store, say, an expanded
  # data object in an existing bucket, add the new field to the schema and
  # reset the bucket schema before storing objects of the new structure. Note
  # that dynamic changes to a bucket schema do not affect the data objects
  # already stored by Jiak. Schema designations only affect structured Jiak
  # interaction, not the data itself.
  #
  # The fields are kept as symbols or strings in four attribute arrays:
  # <code>allowed_fields</code>:: Allowed in Jiak interaction.
  # <code>required_fields</code>:: Required during Jiak interaction.
  # <code>write_mask</code>:: Allowed to be written during a Jiak store.
  # <code>read_mask</code>:: Returned by Jiak on a retrieval.
  #
  # Since Jiak interaction is JSON, duplicate fields names within an array are
  # not meaningful, including a symbol that "equals" a string. Duplicates
  # raise an exception.
  #
  # ===Usage
  # <pre>
  #   schema = JiakSchema.new({:allowed_fields => [:foo,:bar,:baz],
  #                            :required_fields => [:foo,:bar],
  #                            :read_mask => [:foo,:baz],
  #                            :write_mask => [:foo,:bar] })
  #
  #   schema.required_fields                         # => [:foo,:bar]
  #
  #
  #   schema = JiakSchema.new({:allowed_fields => [:foo,:bar,:baz],
  #                            :required_fields => [:foo,:bar]})
  #
  #   schema.read_mask                               # => [:foo,:bar,:baz]
  #   schema.required_fields                         # => [:foo,:bar]
  #   schema.required_fields = [:foo,:bar,:baz]
  #   schema.required_fields                         # => [:foo,:bar,:baz]
  #
  #
  #   schema = JiakSchema.new([:foo,:bar,:baz])
  #
  #   schema.write_mask                              # => [:foo,:bar,:baz)
  #
  # </pre>
  class JiakSchema

    attr_accessor :allowed_fields, :required_fields, :read_mask, :write_mask

    # call-seq:
    #    JiakSchema.new(arg)  -> JiakSchema
    #
    # New schema from either a hash or an single-element array.
    # 
    # ====Hash structure
    # <em>required</em>
    # <code>allowed_fields</code>:: Fields that can be stored.
    # <em>optional</em> 
    # <code>required_fields</code>:: Fields that must be provided on storage.
    # <code>read_mask</code>:: Fields returned on retrieval.
    # <code>write_mask</code>:: Fields that can be changed and stored.
    # The value for key must be an array.
    #
    # =====OR
    # <code>schema</code>: A hash whose value is the above hash structure.
    #
    # Notes
    # * Keys can either be symbols or strings.
    # * Array fields must be symbols or strings.
    # * Required fields defaults to an empty array.
    # * Masks default to the <code>allowed_fields</code> array.
    #   
    # ====Array structure
    # <code>[:f1,...,fn]</code>:: Allowed fields as symbols or strings.
    #
    # All other fields take the same value as the <code>allowed_fields</code>
    # element. The array structure is provided for simplicity but does not
    # provide the finer-grained control of the hash structure.
    #
    # Raise JiakSchemaException if:
    # * the method argument is not either a hash or array
    # * The fields are not either symbols or strings
    # * The fields elements are not unique
    def initialize(arg)
      case arg
      when Hash
        # Jiak returns a JSON structure with a single key 'schema' whose value
        # is a hash. If the arg hash has a schema key, set the opts hash to
        # that; otherwise use the arg as the opts hash.
        opts = arg[:schema] || arg['schema'] || arg

        opts[:allowed_fields] ||= opts['allowed_fields']
        check_arr("allowed_fields",opts[:allowed_fields])

        # Use required if provided, otherwise set to empty array
        opts[:required_fields] ||= opts['required_fields'] || []
        check_arr("required_fields",opts[:required_fields])
        
        # Use masks if provided, otherwise set to allowed_fields
        [:read_mask,:write_mask].each do |key|
          opts[key] ||= opts[key.to_s] || opts[:allowed_fields]
          check_arr(key.to_s,opts[key])
        end
      when Array
        # An array arg must be a single-element array of the allowed
        # fields. Required fields is set to an empty array and the masks are
        # set to the allowed fields array.
        check_arr("allowed_fields",arg)
        opts = {
          :allowed_fields  => arg,
          :required_fields => [],
          :read_mask       => arg,
          :write_mask      => arg
        }
      else
        raise JiakSchemaException, "Initialize arg must be either hash or array"
      end

      @allowed_fields =  opts[:allowed_fields]
      @required_fields = opts[:required_fields]
      @read_mask =       opts[:read_mask]
      @write_mask =      opts[:write_mask]
    end

    # call-seq:
    #    JiakSchema.from_json(json)  -> JiakSchema
    #
    # Create a JiakSchema from parsed JSON returned by the Jiak server.
    def self.from_jiak(jiak)
      new(jiak)
    end

    # call-seq:
    #    schema.to_jiak  -> JSON
    #
    # Create a representation suitable for sending to a Jiak server. Called by
    # JiakClient when transporting a schema to Jiak.
    def to_jiak
      { :schema =>
        { :allowed_fields  => @allowed_fields,
          :required_fields => @required_fields,
          :read_mask       => @read_mask,
          :write_mask      => @write_mask
        }
      }.to_json
    end

    def allowed_fields=(arr)  # :nodoc:
      check_arr('allowed_fields',arr)
      @allowed_fields = arr
    end
    def required_fields=(arr)  # :nodoc:
      check_arr('required_fields',arr)
      @required_fields = arr
    end
    def read_mask=(arr)  # :nodoc:
      check_arr('read_mask',arr)
      @read_mask = arr
    end
    def write_mask=(arr)  # :nodoc:
      check_arr('write_mask',arr)
      @write_mask = arr
    end

    # call-seq:
    #    schema == other -> true or false
    #
    # Equality -- Two schemas are equal if they contain the same array elements
    # for all attributes, irrespective of order.
    def ==(other)
      (@allowed_fields.same_fields?(other.allowed_fields) &&
       @required_fields.same_fields?(other.required_fields) &&
       @read_mask.same_fields?(other.read_mask) &&
       @write_mask.same_fields?(other.write_mask)) rescue false
    end

    # call-seq:
    #    schema.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a JiakSchema with the
    # same array elements, irrespective of order.
    def eql?(other)
      other.is_a?(JiakSchema) &&
        @allowed_fields.same_fields?(other.allowed_fields)  &&
        @required_fields.same_fields?(other.required_fields) &&
        @read_mask.same_fields?(other.read_mask) &&
        @write_mask.same_fields?(other.write_mask)
    end

    def hash    # :nodoc:
      @allowed_fields.name.hash + @required_fields.hash + 
        @read_mask.hash + @write_mask.hash
    end

    # String representation of this schema.
    def to_s
      'allowed_fields="'+@allowed_fields.inspect+
        '",required_fields="'+@required_fields.inspect+
        '",read_mask="'+@read_mask.inspect+
        '",write_mask="'+@write_mask.inspect+'"'
    end

    # Each option must be an array of symbol or string elements.
    def check_arr(desc,arr)
      if(arr.eql?("*"))
        raise(JiakSchemaException,
              "RiakRest does not support wildcard schemas at this time.")
      end
      unless arr.is_a?(Array)
        raise JiakSchemaException, "#{desc} must be an array"
      end
      arr.each do |field| 
        unless(field.is_a?(String) || field.is_a?(Symbol)) 
          raise JiakSchemaException, "#{desc} must be strings or symbols"
        end
      end
      unless arr.map{|f| f.to_s}.uniq.size == arr.size
        raise JiakSchemaException, "#{desc} must have unique elements."
      end
    end
    private :check_arr

  end

end
