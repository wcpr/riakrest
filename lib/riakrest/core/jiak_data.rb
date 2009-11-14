module RiakRest

  # All end-user data stored via RiakRest is contained in user-defined data
  # objects. To make a user-defined data object, include module JiakData into
  # your class definition. This allows creating a class that can be used to
  # create instances of your user-defined data. Note JiakData does create
  # user-data instances, rather it facilitates creating the class you use to
  # create user-data instances.
  #
  # The four class methods <code>allow, require, readable, writable</code>
  # defined in JiakData#ClassMethods are used to declare the schema for
  # structured Jiak interaction with user-defined data. The <code>allow</code>
  # method is mandatory; the other methods take the defaults as described in
  # JiakSchema. See JiakSchema for discussion on structured data interaction.
  #
  # User-defined data classes must override JiakData#ClassMethods#jiak_create
  # (creating your user-defined data from the information returned by Jiak) and
  # JiakData#to_jiak (providing the information to be sent to Jiak). The
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
  #     allow    :foo, :bar, :baz
  #     require  :foo
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
  #     def to_jiak
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
  # <code>to_jiak</code> only provides the <code>writable</code> fields for
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
  # <code>writable</code> fields be the same as <code>allow</code>. Setting
  # only <code>allow</code> fields provide this reasonable default, hence only
  # that call is mandatory.
  module JiakData

    # ----------------------------------------------------------------------
    #   Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for use in creating a user-defined JiakData. The methods
    # <code>allow, require, readable, writable</code> delegate to JiakSchema. 
    # See JiakSchema for discussion on the use of schemas in Riak.
    module ClassMethods

      # :call-seq:
      #   allow :f1, ..., :fn   -> array
      #   allow [:f1, ..., :fn]   -> array
      #
      # Fields allowed in Jiak interactions. Returns an array of the allowed
      # fields.
      #
      # The field <code>jiak</code> is reserved for RiakRest.
      #
      # Raise JiakDataException if the fields include <code>jiak</code>.
      def allow(*fields)
        delegate_schema("allow",*fields)
      end

      # :call-seq:
      #   require :f1, ..., :fn  -> array
      #   require [:f1, ..., :fn]   -> array
      #
      # Fields required during in Jiak interactions. Returns an array of the
      # required fields.
      #
      def require(*fields)
        delegate_schema("require",*fields)
      end

      # :call-seq:
      #   readable :f1, ..., :fn  -> array
      #   readable [:f1, ..., :fn]  -> array
      #
      # Fields returned by Jiak on retrieval. Returns an array of the fields in
      # the read mask.
      #
      def readable(*fields)
        delegate_schema("readable",*fields)
      end

      # :call-seq:
      #   writable :f1, ..., :fn  -> arry
      #   writable [:f1, ..., :fn]  -> arry
      #
      # Fields that can be written during Jiak interaction. Returns an array of
      # the fields in the write mask.
      #
      def writable(*fields)
        delegate_schema("writable",*fields)
      end

      # :call-seq:
      #   readwrite :f1, ..., :fn  -> array
      #   readwrite [:f1, ..., :fn]  -> array
      #
      # Set the read and write masks to the same fields. Returns an array of
      # the fields in the masks.
      def readwrite(*fields)
        delegate_schema("readwrite",*fields)
      end

      def delegate_schema(method,*fields)
        if(fields.include?(:jiak) || fields.include?('jiak'))
          raise JiakDataException, "field 'jiak' reserved for RiakRest"
        end
        @schema ||= JiakSchema.new
        @schema.send(method,*fields)
        unless method.eql?("require")
          fields.each {|field| attr_accessor field}
        end
        schema
      end
      private :delegate_schema
      
      # :call-seq:
      #   JiakData.schema  -> JiakSchema
      #
      # Get a JiakSchema representation this data.
      def schema
        @schema ||= JiakSchema.new
        @schema.dup
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
      # Raise JiakDataException if not explicitly defined by user-data class.
      def jiak_create(json)
        raise JiakDataException, "#{self} must define jiak_create"
      end

    #   def transform_fields(*fields)
    #     fields = fields[0] if(fields[0].is_a?(Array))
    #     fields.map {|f| f.to_sym}
    #   end
    #   private :transform_fields

    #   def check_allowed(fields)
    #     allowed_fields = @schema.allowed_fields
    #     fields.each do |field|
    #       unless allowed_fields.include?(field)
    #         raise JiakDataException, "field '#{field}' not allowed"
    #       end
    #     end
    #   end
    #   private :check_allowed
    end

    def self.included(including_class)  # :nodoc:
      including_class.extend(ClassMethods)
    end
    
    # ----------------------------------------------------------------------
    #   Instance methods
    # ----------------------------------------------------------------------

    # :call-seq:
    #   to_jiak  -> hash
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
    #    def to_jiak
    #      { :writable_f1 => @writable_f1,
    #        :writable_f2 => @writable_f2
    #      }
    #    end
    # </code>
    #
    # Raise JiakDataException if not explicitly defined by user-defined data class.
    def to_jiak
      raise JiakDataException, "#{self} must define to_jiak"
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
