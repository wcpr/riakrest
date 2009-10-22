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
  # throw JiakDataException to enforce this override.
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
  #   end
  # </code>
  #
  # Note that FooBarBaz <code>bar</code> is readable but not writable and
  # <code>baz</code> is writable but not readable. Also note
  # <code>for_jiak</code> only provides the <code>writable</code> fields for
  # writing to the Jiak server and <code>jiak_create</code> only initializes
  # from the <code>readable</code> fields returned by the Jiak server.
  #
  # Under these constraints a user of FooBarBaz could change <code>baz</code>
  # but not see that change and could access <code>bar</code> but not change
  # it. This would be useful if either another JiakData class created access
  # into the same data allowing <code>bar</code> writes and <code>baz</code>
  # reads or if Riak server-side manipulation affected those fields. The
  # constraints declared in FooBarBaz simply provide structured interaction
  # with the data on the Jiak server.
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
        instance_variable_set("@allowed_fields",arr_fields)
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
        arr_fields
      end

      # :call-seq:
      #   JiakData.allowed_fields  -> []
      #
      # Gets the array of allowed fields for a JiakData class.
      def allowed_fields
        @allowed_fields
      end

      # :call-seq:
      #   JiakData.required_fields  -> []
      #
      # Gets the array of required fields for a JiakData class.
      def required_fields
        @required_fields ? @required_fields : []
      end

      # :call-seq:
      #   JiakData.read_mask  -> []
      #
      # Gets the array of fields in the read mask for a JiakData class.
      def read_mask
        @read_mask ? @read_mask : @allowed_fields
      end

      # :call-seq:
      #   JiakData.write_mask  -> []
      #
      # Gets the array of fields in the write mask for a JiakData class.
      def write_mask
        @write_mask ? @write_mask : @allowed_fields
      end
      
      # :call-seq:
      #   JiakData.schema  -> JiakSchema
      #
      # Get a JiakSchema representation determined by
      # <code>allowed, required, readable, writable</code>.
      #
      def schema
        JiakSchema.create(:allowed_fields => @allowed_fields,
                          :required_fields => @required_fields,
                          :read_mask => @read_mask,
                          :write_mask => @write_mask)
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
        allowed_fields = instance_variable_get("@allowed_fields")
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
    # default implementation throws JiakDataException to force this override.
    #
    # The fields returned by this method should come from the
    # <code>writable</code> fields. A simple implementation would look like:
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

    def keygen  # :nodoc:
      nil
    end

  end
end

