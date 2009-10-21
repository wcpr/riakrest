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
  # Given the above definition, for FooBarBaz to be useful would require Riak
  # server-side data manipulation since <code>bar</code> is readable but not
  # writable and <code>baz</code> is writable but not readable. Note that
  # <code>FooBarBase.jiak_create</code> initializes from <code>readable</code>
  # fields and <code>for_jiak</code> sends only writable fields to Jiak. If you
  # do not have Riak server-side manipulations in place having the readable and
  # writable fields be the same as <code>allowed_fields</code> is
  # reasonable. This is the default, so only setting the
  # <code>allowed_fields</code> array via <code>allowed</code> method achieves
  # this behavior.
  module JiakData

    # Class methods for use in creating a user-defined JiakData class. The four
    # methods <code>allowed, required, readable, writable</code> define the
    # JiakSchema for this JiakData. See JiakSchema for discussion on the use of
    # schemas in Riak.
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
      
    end

    # :call-seq:
    #   JiakData.for_jiak
    #
    # Override to return the structure for the data to be written to Jiak. The
    # default implementation throws JiakDataException to force this override.
    #
    # A simple implementation is:
    # <pre>
    #  CxTBD
    # </pre>
    #
    def for_jiak
      raise JiakDataException, "#{self} must define for_jiak"
    end

    def self.included(including_class)  # :nodoc:
      including_class.extend(ClassMethods)
    end
    
  end
end

