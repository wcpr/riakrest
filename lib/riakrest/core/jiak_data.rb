module RiakRest

  # All end-user data stored via RiakRest is contained in user-defined data
  # objects. To make a user-defined data object, include module JiakData into
  # your class definition. This allows creating a class that can be used to
  # create instances of your user-defined data. Note JiakData does create
  # user-data instances, rather it facilitates creating the class you use to
  # create user-data instances.
  #
  # The four class methods <code>allowed, required, readable, writable</code>
  # defined in JiakData#ClassMethods are used to declare the schema for
  # structured Jiak interaction with user-defined data. The <code>allowed</code>
  # method is mandatory; the other methods take the defaults as described in
  # JiakSchema. See JiakSchema for discussion on structured data interaction.
  #
  # User-defined data classes must override JiakData#ClassMethods#jiak_create
  # (creating your user-defined data from the information returned by Jiak) and
  # JiakData#for_jiak (providing the information to be sent to Jiak). The
  # default implementations of these methods throw JiakDataException to
  # enforce this override.
  #
  # JiakData provides a default data key generator that returns nil, which
  # instructs the Jiak server to generate a random key on first data
  # storage. To explicitly set the key override JiakData#keygen to return
  # whatever string you want to use for the key. Keys need to be unique within
  # each bucket on the Jiak server but can be the same across distinct buckets.
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
  # a particular structured interaction of data on a Jiak server.
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
      #   allowed :f1, ..., :fn   -> array
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
      #   required :f1, ..., :fn  -> array
      #
      # Fields required during in Jiak interactions. Returns an array of the
      # required fields.
      #
      def required(*fields)
        set_fields('required_fields',*fields)
      end

      # :call-seq:
      #   readable :f1, ..., :fn  -> array
      #
      # Fields returned by Jiak on retrieval. Returns an array of the fields in
      # the read mask.
      #
      def readable(*fields)
        set_fields('read_mask',*fields)
      end

      # :call-seq:
      #   writable :f1, ..., :fn  -> arry
      #
      # Fields that can be written during Jiak interaction. Returns an array of
      # the fields in the write mask.
      #
      def writable(*fields)
        set_fields('write_mask',*fields)
      end

      # :call-seq:
      #   readwrite :f1, ..., :fn  -> array
      #
      # Set the read and write masks to the same fields. Returns an array of
      # the fields in the masks.
      def readwrite(*fields)
        arr_fields = set_fields('readwrite',*fields)
        arr_fields
      end

      def set_fields(which,*fields)
        arr_fields = create_array(fields)
        check_allowed(arr_fields)
        @schema.send("#{which}=",arr_fields)
        arr_fields
      end
      private :set_fields
      
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
      #  JiakData.jiak_create(jiak)  -> JiakData
      #
      # Create an instance of user-defined data object from the fields read
      # by Jiak. These fields are determined by the read mask of the
      # structured Jiak interaction. See JiakSchema for read mask discussion.
      #
      # User-defined data classes must override this method. The method is
      # called during the creation of a JiakObject from information returned by
      # Jiak. The JiakObject contains the user-defined data itself. You do not
      # call this method explicitly.
      #
      # ====Example
      # <code>
      #    def initialize(f1,f2)
      #      @f1 = f1
      #      @f2 = f2
      #    end
      #    def jiak_create(jiak)
      #      new(jiak['f1'], jiak['f2'])
      #    end
      # </code>
      #
      # Raise JiakDataException if not explicitly defined by user-defined data class.
      def jiak_create(json)
        raise JiakDataException, "#{self} must define jiak_create"
      end

      def create_array(*fields)
        if(fields.size == 1 && fields[0].is_a?(Array))
          array = fields[0]
        else
          array = fields
        end
        array.map {|field| field}
        array
      end
      private :create_array

      def check_allowed(fields)
        allowed_fields = @schema.allowed_fields
        fields.each do |field|
          unless allowed_fields.include?(field)
            raise JiakDataException, "field '#{field}' not allowed"
          end
        end
      end
      private :check_allowed
    end

    def self.included(including_class)  # :nodoc:
      including_class.extend(ClassMethods)
    end
    
    # ----------------------------------------------------------------------
    #   Instance methods
    # ----------------------------------------------------------------------

    # :call-seq:
    #   for_jiak  -> hash
    #
    # Provide a hash structure of the data to write to Jiak. The fields for
    # this structure should come from the write mask of the structured Jiak
    # interaction.  See JiakSchema for write mask discussion.
    #
    # User-defined data classes must override this method. The method is called
    # during the creation of a JiakObject to send information to Jiak. The
    # JiakObject contains the user-defined data itself. You do not call this
    # method explicitly.
    #
    # ====Example
    # <code>
    #    def for_jiak
    #      { :writable_f1 => @writable_f1,
    #        :writable_f2 => @writable_f2
    #      }
    #    end
    # </code>
    #
    # Raise JiakDataException if not explicitly defined by user-defined data class.
    def for_jiak
      raise JiakDataException, "#{self} must define for_jiak"
    end

    # :call-seq:
    #   keygen   -> string
    #
    # Generate Jiak key for data. Default implementation returns
    # <code>nil</code> which instructs the Jiak server to generate a random
    # key. Override for user-defined data behaviour.
    #
    # ====Example
    # A simple implementation would look like:
    # <code>
    #   def keygen
    #     f1.to_s
    #   end
    # </code>
    def keygen
      nil
    end

  end
end

