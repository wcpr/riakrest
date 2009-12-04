module RiakRest

  # All end-user data stored via RiakRest is contained in user-defined data
  # objects. To make a user-defined data object, include module JiakData into
  # your class definition. This allows creating a class that can be used to
  # create instances of your user-defined data. Note JiakData does not create
  # user-data instances, rather it facilitates creating the class used to
  # create user-data instances.
  #
  # The class methods <code>attr_reader,attr_writer</code>, and
  # <code>attr_accessor</code> are used to declare the Jiak readable and
  # writable fields for a JiakData. The method <code>keygen</code> is used
  # to specify a block for generating the key for a data instance. By default,
  # JiakData generates an empty key which is interpreted by the Jiak server as
  # a signal to generate a random key.
  # ====Example
  #  class FooBar
  #    include JiakData
  #    attr_accessor :foo, :bar
  #    keygen { foo.downcase }
  #  end
  #
  # The four class methods <code>allow, require, readable, writable</code> are
  # used for more specific data schema control. See JiakSchema for a
  # discussion of the schema fields.
  # ====Example
  #  class FooBarBaz
  #    include JiakData
  #
  #    allow    :foo, :bar, :baz
  #    require  :foo
  #    readable :foo, :bar
  #    writable :foo, :baz
  #  end
  #
  # The methods used in the above examples can be used together as well.
  #
  # The Core Client framework uses a JiakData class to marshall data to and
  # from the Jiak server. Marshalling to the Jiak server uses JiakData#to_jiak
  # and marshalling from the Jiak server uses
  # JiakData#ClassMethods#jiak_create. Implementations of these methods are
  # automatically generated to marshall writable fields to Jiak and initialize
  # from readable fields.
  #
  module JiakData

    # ----------------------------------------------------------------------
    #   Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for use in creating a user-defined JiakData. The methods
    # <code>allow, require, readable, writable</code> delegate to JiakSchema. 
    # See JiakSchema for discussion on the use of schemas in Riak.
    module ClassMethods

      # :call-seq:
      #   attr_reader :f1,...,:fn
      #
      # Add read accessible fields.
      def attr_reader(*fields)
        readable *fields
        nil
      end
      alias :attr :attr_reader

      # :call-seq:
      #   attr_writer :f1,...,:fn
      #
      # Add write accessible fields.
      def attr_writer(*fields)
        writable *fields
        nil
      end

      # :call-seq:
      #   attr_accessor :f1,...,:fn
      #
      # Add read/write accessible fields.
      def attr_accessor(*fields)
        readable *fields
        writable *fields
      end

      # :call-seq:
      #   allow :f1, ..., :fn   -> array
      #   allow [:f1, ..., :fn]   -> array
      #
      # Adds to the fields allowed in Jiak interactions.
      #
      # Returns an array of added fields.
      #
      # Raise JiakDataException if the fields include <code>jiak</code>.
      def allow(*fields)
        expand_schema("allow",*fields)
      end

      # :call-seq:
      #   require :f1, ..., :fn  -> array
      #   require [:f1, ..., :fn]   -> array
      #
      # Adds to the fields required during in Jiak interactions.
      #
      # Returns an array of added fields.
      def require(*fields)
        expand_schema("require",*fields)
      end

      # :call-seq:
      #   readable :f1, ..., :fn  -> array
      #   readable [:f1, ..., :fn]  -> array
      #
      # Adds to the fields that can be read from Jiak.
      #
      # Returns an array of added fields.
      def readable(*fields)
        expand_schema("readable",*fields)
      end

      # :call-seq:
      #   writable :f1, ..., :fn  -> arry
      #   writable [:f1, ..., :fn]  -> arry
      #
      # Adds to the fields that can be written to Jiak.
      #
      # Returns an array of added fields.
      def writable(*fields)
        expand_schema("writable",*fields)
      end

      # :call-seq:
      #   readwrite :f1, ..., :fn  -> nil
      #   readwrite [:f1, ..., :fn]  -> nil
      #
      # Adds to the fields that can be read and written.
      #
      # Returns nil
      def readwrite(*fields)
        readable(*fields)
        writable(*fields)
        nil
      end

      # Delegates adding fields to the schema, then creates attr accessors for
      # each field added.
      def expand_schema(method,*fields)
        @schema ||= JiakSchema.new
        prev_allowed = @schema.allowed_fields
        added_fields = @schema.send(method,*fields)
        added_allowed = @schema.allowed_fields - prev_allowed
        # added_allowed.each {|field| attr_accessor field}
        added_allowed.each do |field| 
          class_eval <<-EOH
            def #{field}
              @#{field}
            end
            def #{field}=(val)
              @#{field} = val
            end
          EOH
        end
        added_fields
      end
      private :expand_schema
      
      # :call-seq:
      #   JiakData.schema  -> JiakSchema
      #
      # Get a JiakSchema representation this data.
      def schema
        @schema ||= JiakSchema.new
      end

      # :call-seq:
      #   JiakData.keygen(&block)  -> nil
      #
      # Define the key generation for an instance of the created JiakData
      # class. Key generation will call the specified block in the scope of the
      # current instance.
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
      # User-defined data classes must either override this method explicitly
      # or use the <code>attr_*</code> methods which implicitly override this
      # method. The method is automatically called to marshall data from
      # Jiak. You do not call this method explicitly.
      #
      # ====Example
      #  def initialize(f1,f2)
      #    @f1 = f1
      #    @f2 = f2
      #  end
      #  def jiak_create(jiak)
      #    new(jiak['f1'], jiak['f2'])
      #  end
      def jiak_create(jiak)
        new(jiak)
      end

    end

    def self.included(including_class)  # :nodoc:
      including_class.extend(ClassMethods)

      define_method(:to_jiak) do
        self.class.schema.write_mask.inject({}) do |build,field|
          build[field] = send("#{field}")
          build
        end
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

    def initialize(hash={})
      hash.each {|k,v| instance_variable_set("@#{k}", v)}
    end

    # :call-seq:
    #   to_jiak  -> hash
    #
    # Provide a hash structure of the data to write to Jiak. The fields for
    # this structure should come from the JiakData write mask. See JiakSchema
    # for shema discussion.
    #
    # User-defined data classes must either override this method explicitly or
    # use the <code>attr_*</code> methods which implicitly provide an implicit
    # override. The method is automatically called to marshall data to
    # Jiak. You do not call this method explicitly.

    # Data classes that do not used the attr_* methods to specify attributes
    # must override this method. 
    #
    # ====Example
    #  def to_jiak
    #    { :writable_f1 => @writable_f1,
    #      :writable_f2 => @writable_f2
    #    }
    #  end
    def to_jiak
      self.class.schema.write_mask.inject({}) do |build,field|
        build[field] = send("#{field}")
        build
      end
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
    #  def keygen
    #    f1.to_s
    #  end
    #
    # The JiakData#ClassMethods#keygen class method can also be used to
    # override this default implement method.
    def keygen
      nil
    end

  end
end
