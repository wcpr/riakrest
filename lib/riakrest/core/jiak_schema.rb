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
  # At this time, Riak does not support concurrent bucket access with different
  # schemas, so the bucket interactions is semi-static.
  #
  # The fields are kept as symbols or strings in four attribute arrays:
  # <code>allowed_fields</code>:: Allowed in Jiak interaction.
  # <code>required_fields</code>:: Required during Jiak interaction.
  # <code>write_mask</code>:: Allowed to be written during a Jiak store.
  # <code>read_mask</code>:: Returned by Jiak on a retrieval.
  #
  # Since Jiak interaction is JSON, duplicate fields names within an array are
  # not meaningful, including a symbol that "equals" a string. Duplicates
  # fields are ignored.
  #
  # Riak supports wild cards in schemas. The wild card is specified using the
  # constant JiakSchema::WILDCARD. The constant JiakSchema::WIDE_OPEN specifies
  # a wide open schema with allowed_fields, read_mask, and write_mask all set
  # to JiakSchema::WILDCARD, and required_fields set to an empty array. The
  # wide open schema allows the least restricted interaction with Jiak server
  # data. An initially created Riak bucket has the wide open schema setting.
  #
  # ===Usage
  # <pre>
  #   schema = JiakSchema.new([:foo,:bar])
  #   schema.allowed_fields                          # => [:foo,:bar]
  #   schema.required_fields                         # => []
  #   schema.read_mask                               # => [:foo,:bar]
  #   schema.write_mask                              # => [:foo,:bar]
  #
  #   schema.write :baz
  #   schema.allowed_fields                          # => [:foo,:bar,:baz]
  #   schema.read_mask                               # => [:foo,:bar]
  #   schema.write_mask                              # => [:foo,:bar,:baz]
  #
  # </pre>
  class JiakSchema

    # Wild card constant.
    WILDCARD = "*"
    WILDCARD.freeze

    attr_accessor :allowed_fields, :required_fields, :read_mask, :write_mask

    # call-seq:
    #    JiakSchema.new(arg)  -> JiakSchema
    #
    # New schema from either a hash or an single-element array.
    # 
    # ====Hash structure
    # <code>allowed_fields</code>:: Fields that can be stored.
    # <code>required_fields</code>:: Fields that must be provided on storage.
    # <code>read_mask</code>:: Fields returned on retrieval.
    # <code>write_mask</code>:: Fields that can be changed and stored.
    #
    # =====OR
    # <code>schema</code>: A hash whose value is in the above hash structure.
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
    def initialize(arg=nil)
      case arg
      when Hash
        # Jiak returns a JSON structure with a single key 'schema' whose value
        # is a hash. If the arg hash has a schema key, set the opts hash to
        # that; otherwise use the arg as the opts hash.
        opts = arg[:schema] || arg['schema'] || arg

        opts[:allowed_fields] ||= opts['allowed_fields']
        opts[:allowed_fields] = transform_fields("allowed_fields",
                                                 opts[:allowed_fields])

        # Use required if provided, otherwise set to empty array
        opts[:required_fields] ||= opts['required_fields'] || []
        opts[:required_fields] = transform_fields("required_fields",
                                                  opts[:required_fields])
        
        # Use masks if provided, otherwise set to allowed_fields
        [:read_mask,:write_mask].each do |key|
          opts[key] ||= opts[key.to_s] || opts[:allowed_fields]
          opts[key] = transform_fields(key.to_s,opts[key])
        end
      when Array
        # An array arg must be a single-element array of the allowed
        # fields. Required fields is set to an empty array and the masks are
        # set to the allowed fields array.
        arg = transform_fields("allowed_fields",arg)
        opts = {
          :allowed_fields  => arg,
          :required_fields => [],
          :read_mask       => arg,
          :write_mask      => arg
        }
      when String
        unless(arg.eql?(WILDCARD))
          raise JiakSchemaException, "Initialize string can only be WILDCARD"
        end
        opts = {
          :allowed_fields  => WILDCARD,
          :required_fields => [],
          :read_mask       => WILDCARD,
          :write_mask      => WILDCARD
        }
      when nil
        arr = []
        opts = {
          :allowed_fields  => arr,
          :required_fields => arr,
          :read_mask       => arr,
          :write_mask      => arr
        }
      else
        raise JiakSchemaException, "Illegal initialize arg"
      end
      
      # Dup to protect internal arrays from those passed into initialize
      @allowed_fields  = opts[:allowed_fields].dup
      @required_fields = opts[:required_fields].dup
      @read_mask       = opts[:read_mask].dup
      @write_mask      = opts[:write_mask].dup
    end

    # Wide open schema constant.
    WIDE_OPEN = JiakSchema.new(WILDCARD)
    WIDE_OPEN.freeze

    # call-seq:
    #    JiakSchema.from_json(json)  -> JiakSchema
    #
    # Called by the Core Client framework when marshalling from Jiak. This
    # method does not need to be call explicitly.
    def self.jiak_create(jiak)
      new(jiak)
    end

    # :call-seq:
    #    to_jiak  -> JSON
    #
    # Called by the Core Client framework when marshalling to Jiak. This method
    # does not need to be call explicitly.
    def to_jiak
      { :schema =>
        { :allowed_fields  => @allowed_fields,
          :required_fields => @required_fields,
          :read_mask       => @read_mask,
          :write_mask      => @write_mask
        }
      }
    end

    # :call-seq:
    #   allowed_fields = array
    #
    # Set the allowed fields array. Overrides whatever fields were in the array.
    # Use JiakSchema#allow to add fields to the array.
    def allowed_fields=(arr)  # :nodoc:
      @allowed_fields = transform_fields('allowed_fields',arr)
    end

    # :call-seq:
    #   required_fields = array
    #
    # Set the required fields array. Overrides whatever fields were in the
    # array.  Use JiakSchema#require to add fields to the array.
    def required_fields=(arr)  # :nodoc:
      @required_fields = transform_fields('required_fields',arr)
    end

    # :call-seq:
    #   read_mask = array
    #
    # Set the read mask array. Overrides whatever fields were in the array.
    # Use JiakSchema#readable to add fields to the array.
    def read_mask=(arr)  # :nodoc:
      @read_mask = transform_fields('read_mask',arr)
    end

    # :call-seq:
    #   write_mask = array
    #
    # Set the write mask array. Overrides whatever fields were in the array.
    # Use JiakSchema#writable to add fields to the array.
    def write_mask=(arr)  # :nodoc:
      @write_mask = transform_fields('write_mask',arr)
    end

    # :call-seq:
    #   schema.readwrite = [:f1,...,:fn]
    #
    # Set the read and write masks for a JiakSchema.
    def readwrite=(arr)   # :nodoc:
      mask = transform_fields('readwrite',arr)
      @read_mask = mask
      @write_mask = mask
    end

    # :call-seq:
    #   allow(:f1,...,:fn) -> array
    #   allow([:f1,...,:fn]) -> array
    #
    # Add to the allowed fields array. Overwrites JiakSchema::WILDCARD array.
    #
    # Returns fields added to allowed fields.
    def allow(*fields)
      added_fields = add_fields(@allowed_fields,"allow",fields)
      @allowed_fields = added_fields  if(@allowed_fields.eql?(WILDCARD))
      added_fields
    end

    # :call-seq:
    #   require(:f1,...,:fn) -> array
    #   require([:f1,...,:fn]) -> array
    #
    # Add fields to the required fields array. Adds the fields to the allowed
    # fields as well.
    #
    # Returns fields added to required_fields.
    def require(*fields)
      added_fields = add_fields(@required_fields,"require",fields)
      readwrite(*fields)
      added_fields
    end

    # :call-seq:
    #   readable(:f1,...,:fn) -> array
    #   readable([:f1,...,:fn]) -> array
    #
    # Add fields to the read mask array.  Adds the fields to the allowed
    # fields as well. Overwrites JiakSchema::WILDCARD arrays.
    #
    # Returns fields added to read_mask
    def readable(*fields)
      added_fields = add_fields(@read_mask,"readable",fields)
      allow(*fields)
      @read_mask = added_fields if(@read_mask.eql?(WILDCARD))
      added_fields
    end

    # :call-seq:
    #   writable(:f1,...,:fn) -> array
    #   writable([:f1,...,:fn]) -> array
    #
    # Add fields to the write mask array.  Adds the fields to the allowed
    # fields as well. Overwrites JiakSchema::WILDCARD arrays.
    #
    # Returns fields added to write_mask
    def writable(*fields)
      added_fields = add_fields(@write_mask,"writable",fields)
      allow(*fields)
      @write_mask = added_fields if(@write_mask.eql?(WILDCARD))
      added_fields
    end

    # :call-seq:
    #   readwrite(:f1,...,:fn) -> nil
    #   readwrite([:f1,...,:fn]) -> nil
    #
    # Add fields to the read and write mask arrays. Adds the fields to the
    # allowed fields as well. Overwrites JiakSchema::WILDCARD arrays.
    #
    # Returns nil.
    def readwrite(*fields)
      readable(*fields)
      writable(*fields)
      allow(*fields)
      nil
    end

    # Scrub the fields by changing strings to symbols and removing any dups,
    # then add new fields to arr and return added fields.
    def add_fields(arr,descr,fields)
      fields = fields[0] if(fields.size == 1 && fields[0].is_a?(Array))
      scrubbed = transform_fields(descr,fields)
      if(arr.eql?(WILDCARD))
        arr = scrubbed
      else
        (scrubbed - arr).each {|f| arr << f}
      end
    end
    private :add_fields

    # :call-seq:
    #   allowed_fields -> array
    #
    # Return an array of the allowed fields. This array is a copy and cannot
    # be used to update the allowed_fields array itself. Use JiakSchema#allow
    # to add fields or JiakSchema#allowed_fields= to set the array.
    def allowed_fields
      @allowed_fields.dup
    end

    # :call-seq:
    #   required_fields -> array
    #
    # Return an array of the allowed fields. This array is a copy and cannot
    # be used to update the required_fields array itself. Use JiakSchema#require
    # to add fields or JiakSchema#required_fields= to set the array.
    def required_fields
      @required_fields.dup
    end

    # :call-seq:
    #   read_mask -> array
    #
    # Returns an array of the allowed fields. This array is a copy and cannot
    # be used to update the read_mask array itself. Use JiakSchema#readable
    # to add fields or JiakSchema#read_mask= to set the array.
    def read_mask
      @read_mask.dup
    end

    # :call-seq:
    #   write_mask -> array
    #
    # Returns an array of the allowed fields. This array is a copy and cannot
    # be used to update the write_mask array itself. Use JiakSchema#writable
    # to add fields or JiakSchema#write_mask= to set the array.
    def write_mask
      @write_mask.dup
    end

    # call-seq:
    #    schema == other -> true or false
    #
    # Equality -- Two schemas are equal if they contain the same array elements
    # for all attributes, regardless of order.
    def ==(other)
      (compare_fields(@allowed_fields,other.allowed_fields)  &&
       compare_fields(@required_fields,other.required_fields) &&
       compare_fields(@read_mask,other.read_mask) &&
       compare_fields(@write_mask,other.write_mask)) rescue false
    end

    # call-seq:
    #    schema.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a JiakSchema with the
    # same array elements, regardless of order.
    def eql?(other)
      other.is_a?(JiakSchema) &&
        compare_fields(@allowed_fields,other.allowed_fields)  &&
        compare_fields(@required_fields,other.required_fields) &&
        compare_fields(@read_mask,other.read_mask) &&
        compare_fields(@write_mask,other.write_mask)
    end

    def compare_fields(arg1,arg2)
      if(arg1.is_a?(Array) && arg2.is_a?(Array))
        arg1.same_fields?(arg2)
      elsif(arg1.is_a?(String) && arg2.is_a?(String))
        arg1.eql?(arg2)
      else
        false
      end
    end

    def hash    # :nodoc:
      @allowed_fields.hash + @required_fields.hash + 
        @read_mask.hash + @write_mask.hash
    end

    # String representation of this schema.
    def to_s
      af = "allowed_fields=#{@allowed_fields.inspect}"
      rf = "required_fields=#{@required_fields.inspect}"
      rm = "read_mask=#{@read_mask.inspect}"
      wm = "write_mask=#{@write_mask.inspect}"
      "#{af},#{rf},#{rm},#{wm}"
    end

    # Check for array of symbol or string elements.
    def transform_fields(desc,arr)
      if(arr.is_a?(Array))
        arr.each do |field| 
          unless(field.is_a?(String) || field.is_a?(Symbol)) 
            raise JiakSchemaException, "#{desc} must be strings or symbols"
          end
        end
        arr.map{|f| f.to_sym}.uniq
      elsif(arr.eql?(WILDCARD))
        arr
      else
        raise JiakSchemaException, "#{desc} must be an array or WILDCARD"
      end
    end
    private :transform_fields

  end

end
