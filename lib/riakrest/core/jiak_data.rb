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
  # storage. To explicitly set the key use either JiakData#keygen to specify a
  # block or define a keygen method which returns whatever string you want to
  # use for the key. Keys need to be unique within each bucket on the Jiak
  # server but can be the same across distinct buckets.
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
  #     keygen { foo.to_s.downcase }
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
      #   jattr_reader :f1,...,:fn
      #
      # Add read accessible fields.
      def jattr_reader(*fields)
        added_fields = readable(*fields)
        added_fields.each do |field|
          class_eval <<-EOS
            def #{field}
              @#{field}
            end
          EOS
        end
        nil
      end
      alias :jattr :jattr_reader

      # :call-seq:
      #   jattr_writer :f1,...,:fn
      #
      # Add write accessible fields.
      def jattr_writer(*fields)
        added_fields = writable(*fields)
        added_fields.each do |field|
          class_eval <<-EOS
            def #{field}=(val)
              @#{field} = val
            end
          EOS
        end
        nil
      end

      # :call-seq:
      #   jattr_accessor :f1,...,:fn
      #
      # Add read/write accessible fields.
      def jattr_accessor(*fields)
        jattr_reader *fields
        jattr_writer *fields
      end

      # :call-seq:
      #   allow :f1, ..., :fn   -> array
      #   allow [:f1, ..., :fn]   -> array
      #
      # Adds to the fields allowed in Jiak interactions.
      #
      # The field <code>jiak</code> is reserved for RiakRest.
      # 
      # Returns an array of added fields.
      #
      # Raise JiakDataException if the fields include <code>jiak</code>.
      def allow(*fields)
        delegate_schema("allow",*fields)
      end

      # :call-seq:
      #   require :f1, ..., :fn  -> array
      #   require [:f1, ..., :fn]   -> array
      #
      # Adds to the fields required during in Jiak interactions.
      #
      # Returns an array of added fields.
      def require(*fields)
        delegate_schema("require",*fields)
      end

      # :call-seq:
      #   readable :f1, ..., :fn  -> array
      #   readable [:f1, ..., :fn]  -> array
      #
      # Adds to the fields that can be read from Jiak.
      #
      # Returns an array of added fields.
      def readable(*fields)
        added_fields = delegate_schema("readable",*fields)
        unless added_fields.empty?
          def jiak_create(jiak)
            new(jiak)
          end
        end
        added_fields
      end

      # :call-seq:
      #   writable :f1, ..., :fn  -> arry
      #   writable [:f1, ..., :fn]  -> arry
      #
      # Adds to the fields that can be written to Jiak.
      #
      # Returns an array of added fields.
      def writable(*fields)
        added_fields = delegate_schema("writable",*fields)
        unless added_fields.empty?
          define_method(:to_jiak) do
            self.class.schema.write_mask.inject({}) do |build,field|
              val = send("#{field}")
              build[field] = val
              build
            end
          end
        end
        added_fields
      end

      # :call-seq:
      #   readwrite :f1, ..., :fn  -> nil
      #   readwrite [:f1, ..., :fn]  -> nil
      #
      # Adds to the fields that can be read and written.
      #
      # Returns nil
      def readwrite(*fields)
        delegate_schema("readwrite",*fields)
      end

      # Delegates adding fields to the schema, then creates attr accessors for
      # each field added.
      def delegate_schema(method,*fields)
        @schema ||= JiakSchema.new
        prev_allowed = @schema.allowed_fields
        added_fields = @schema.send(method,*fields)
        added_allowed = @schema.allowed_fields - prev_allowed
        added_allowed.each {|field| attr_accessor field}
        added_fields
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
      #   JiakData.keygen(&block)  -> nil
      #
      # Define the key generation for an instance of the created JiakData class.
      def keygen(&block)
        define_method(:keygen,&block)
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

      define_method(:initialize) do |hash|
        hash.each {|k,v| instance_variable_set("@#{k}", v)}
      end

      define_method(:eql?) do |other|
        other.is_a?(self.class) &&
          self.class.schema.allowed_fields.reduce(true) do |same,field|
          same && other.send("#{field}").eql?(send("#{field}"))
        end
      end

      define_method(:==) do |other|
        self.class.schema.allowed_fields.reduce(true) do |same,field|
          same && (other.send("#{field}") == (send("#{field}")))
        end
      end

      define_method(:hash) do
        self.class.schema.allowed_fields.inject(0) do |hsh,field|
          hsh += send("#{field}").hash
        end
      end
    end
    
    # ----------------------------------------------------------------------
    #   Instance methods
    # ----------------------------------------------------------------------

    # :call-seq:
    #   to_jiak  -> hash
    #
    # Provide a hash structure of the data to write to Jiak. The fields for
    # this structure should come from the JiakData write mask. See JiakSchema
    # for shema discussion.
    #
    # Data classes that do not used the jattr_* methods to specify attributes
    # must override this method. The method is called during the creation of a
    # JiakObject to send information to Jiak. The JiakObject contains the
    # user-defined data itself. You do not call this method explicitly.
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
    # Raise JiakDataException if not defined by user-defined data class.
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
    #
    # The JiakData#keygen class method can also be used to override this
    # default implement method.
    def keygen
      nil
    end

  end
end
