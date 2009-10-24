module RiakRest

  # All end-user data stored via RiakRest is contained in user-defined JiakData
  # objects. To make a user-defined data object, include this module into your
  # class definition.
  #
  # The four class methods <code>allowed, required, readable, writable</code>
  # defined in JiakData#ClassMethods are used to determine the JiakSchema for
  # this JiakData. The <code>allowed</code> method is mandatory; the other
  # methods take the defaults as described in JiakSchema. See that class for
  # discussion on the use of schemas in Riak.
  #
  # User-defined data classes must override JiakData#ClassMethods#jiak_create
  # and JiakData#for_jiak. The default implementations of these two methods
  # throw JiakDataException to enforce this override. If you want dictate the
  # Jiak server key for your data override JiakData#keygen.
  #
  # ===Example
  # <code>
  #   class FooBarBaz
  #     include JiakData
  #
  #     allowed  :foo, :bar, :baz
  #     required :foo
  #     readable :foo, :bar
  #     writable :foo, :baz
  # 
  #     def initialize(foo,bar,baz)
  #       @foo = foo
  #       @bar = bar
  #       @baz = baz
  #     end
  # 
  #     def self.jiak_create(jiak)
  #       new(jiak['foo'],jiak['bar'])
  #     end
  # 
  #     def for_jiak
  #       { :foo => @foo,
  #         :baz => @baz
  #       }
  #     end
  #
  #     def keygen
  #       "#{foo}"
  #     end
  #   end
  # </code>
  #
  # Note that FooBarBaz <code>bar</code> is readable but not writable and
  # <code>baz</code> is writable but not readable. Also note
  # <code>for_jiak</code> only provides the <code>writable</code> fields for
  # writing to the Jiak server and <code>jiak_create</code> only initializes
  # from the <code>readable</code> fields returned by the Jiak server. The
  # above definition means a user of FooBarBaz could change <code>baz</code>
  # but not see that change and could access <code>bar</code> but not change
  # it. This could be useful if either another JiakData class (with a different
  # schema) created access into the same data, allowing <code>bar</code> writes
  # and <code>baz</code> reads, or if Riak server-side manipulation affected
  # those fields. The constraints declared in FooBarBaz simply provide
  # structured interaction with the data on the Jiak server.
  #
  # If only one JiakData will be used for a particular type of data on the Jiak
  # server it is desirable to have the <code>readable</code> and
  # <code>writable</code> fields be the same as <code>allowed</code>. Setting
  # only <code>allowed</code> fields provide this reasonable default, hence only
  # that call is mandatory.
  module JiakData

    # ----------------------------------------------------------------------
    #   Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for use in creating a user-defined JiakData. The methods
    # <code>allowed, required, readable, writable</code> define the JiakSchema
    # for this JiakData. See JiakSchema for discussion on the use of schemas in
    # Riak.
    module ClassMethods

      # :call-seq:
      #   allowed :field_1, :field_2, ..., :field_n   -> []
      #
      # Fields allowed in Jiak interactions. Returns an array of the allowed
      # fields.
      #
      def allowed(*fields)
        arr_fields = create_array(fields)
        fields.each {|field| attr_accessor field}
        @schema = JiakSchema.new(arr_fields)
        arr_fields
      end

      # :call-seq:
      #   required :field_1, :field_2, ..., :field_n  -> []
      #
      # Fields required during in Jiak interactions. Returns an array of the
      # required fields.
      #
      def required(*fields)
        arr_fields = create_array(fields)
        check_allowed(arr_fields)
        instance_variable_set("@required_fields",arr_fields)
        @schema.required_fields = arr_fields
        arr_fields
      end

      # :call-seq:
      #   readable :field_1, :field_2, ..., :field_n  -> []
      #
      # Fields returned by Jiak on retrieval. Returns an array of the fields in
      # the read mask.
      #
      def readable(*fields)
        arr_fields = create_array(fields)
        check_allowed(arr_fields)
        instance_variable_set("@read_mask",arr_fields)
        @schema.read_mask = arr_fields
        arr_fields
      end

      # :call-seq:
      #   writable :field_1, :field_2, ..., :field_n  -> []
      #
      # Fields that can be written during Jiak interaction. Returns an array of
      # the fields in the write mask.
      #
      def writable(*fields)
        arr_fields = create_array(fields)
        check_allowed(arr_fields)
        instance_variable_set("@write_mask",arr_fields)
        @schema.write_mask = arr_fields
        arr_fields
      end

      
      # :call-seq:
      #   JiakData.schema  -> JiakSchema
      #
      # Get a JiakSchema representation determined by
      # <code>allowed, required, readable, writable</code>.
      #
      def schema
        @schema
      end

      # :call-seq:
      #  JiakData.jiak_create(json)  -> JiakData
      #
      # Create an instance of a JiakData object from JSON. The structure of
      # the JSON is determined by the JiakData.for_jiak method of the JiakData
      # class itself.
      #
      def jiak_create(json)
        raise JiakDataException, "#{self} must define jiak_create"
      end

      private
      def create_array(*fields)
        if(fields.size == 1 && fields[0].is_a?(Array))
          array = fields[0]
        else
          array = fields
        end
        array.map {|field| field}
        array
      end

      def check_allowed(fields)
        allowed_fields = @schema.allowed_fields
        fields.each do |field|
          unless allowed_fields.include?(field)
            raise JiakDataException, "field '#{field}' not allowed"
          end
        end
      end
    end

    def self.included(including_class)  # :nodoc:
      including_class.extend(ClassMethods)
    end
    
    # ----------------------------------------------------------------------
    #   Instance methods
    # ----------------------------------------------------------------------

    # :call-seq:
    #   JiakData.for_jiak
    #
    # Override to return the structure for the data to be written to Jiak. The
    # default implementation throws JiakDataException to force this
    # override. The fields returned by this method should come from the
    # <code>writable</code> fields.
    #
    # ====Example
    # A simple implementation would look like:
    # <code>
    #    def for_jiak
    #      { :writable_field_1 => @writable_field_1,
    #        :writable_field_2 => @writable_field_2
    #      }
    #    end
    # </code>
    #
    def for_jiak
      raise JiakDataException, "#{self} must define for_jiak"
    end

    # :call-seq:
    #   data.keygen   -> string
    #
    # Generate Jiak key for data. Default implementation returns
    # <code>nil</code> which instructs the Jiak server to generate a random
    # key. Override for user-defined data behaviour.
    #
    # ====Example
    # A simple implementation would look like:
    # <code>
    #   def keygen
    #     field_1.to_s
    #   end
    # </code>
    def keygen
      nil
    end

  end
end

