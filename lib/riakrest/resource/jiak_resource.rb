module RiakRest
  # JiakResource provides a resource-oriented wrapper for Jiak interaction. 
  
  module JiakResource
    # ----------------------------------------------------------------------
    # Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for creating a user-defined JiakResource. The methods
    # <code>server</code> and <code>resource</code> are mandatory.
    #
    # ===Usage
    # <code>
    #   class Dog
    #     include JiakResource
    #     server   'http://localhost:8002/jiak'
    #     resource :name => 'dog', :data_class => DogData
    #   end
    # </code>
    # 
    module ClassMethods

      # :call-seq:
      #   JiakServer.server(uri)
      #
      # Set the URI for Jiak server interaction.
      #
      def server(uri)
        jiak.uri = uri
        jiak.server = JiakClient.new(uri)
        uri
      end

      # :call-seq:
      #   JiakResource.resource(opts)
      #
      # Valid options are:
      # <code>data_class</code> :: data class for the resource.
      # <code>name</code> :: Jiak (bucket) name for the resource.
      # <code>activate</code> :: <code>true> to activate this JiakResource at
      # the time of class creation. Default is <code>false</code>.
      #
      # <code>data_class</code> is mandatory. For each field in the data class
      # JiakSchema#allowed_fields accessor methods are added to facilitate
      # manipulating the data wrapped by a JiakResource.
      #
      # If <code>name</code> is not provided the default is to use the name of
      # the data class as the name for the resource.
      #
      # If <code>activate</code> is not provided or set to <code>false</code> a
      # call to JiakResource#activate must preceed any resource interaction
      # with the Jiak server.
      #
      # Raise JiakResourceException if a valid JiakData class is not provided
      # for <code>data_class</code>.
      def resource(opts)
        unless opts[:data_class]
          raise JiakResourceException, "data_class required."
        end
        unless opts[:data_class].include?(JiakData)
          raise JiakResourceException, "data_class must include module JiakData"
        end

        name = opts[:name] || opts[:data_class].to_s.split(/::/).last
        jiak.name = name
        jiak.data = opts[:data_class]
        jiak.bucket = JiakBucket.new(name,opts[:data_class])
        jiak.server.set_schema(jiak.bucket) if opts[:activate] 

        opts[:data_class].schema.allowed_fields.each do |field|
          define_method("#{field}=") do |val|
            @jiak.data.send("#{field}=",val)
          end
          define_method("#{field}") do
            @jiak.data.send("#{field}")
          end
        end
      end
      alias bucket resource

      # :call-seq:
      #   JiakResource.params(opts={})  -> {}
      #
      # Default options for request parameters during Jiak interaction. Valid
      # options are:
      #
      # <code>:reads</code> :: The number of Riak nodes that must successfully read data.
      # <code>:writes</code> :: The number of Riak nodes that must successfully store data.
      # <code>:durable_writes</code> :: The number of Riak nodes (<code>< writes</code>) that must successfully store data in a durable manner.
      # <code>:waits</code> :: The number of Riak nodes that must reply the delete has occurred before success.
      #
      # Request parameters can be set at the JiakResource level using this
      # method, or at the individual call level. The order of precedence for
      # setting each parameter at the time of the Jiak interaction is
      # individual call : JiakResource : Riak cluster. In general the values
      # set on the Riak cluster should suffice and these parameters aren't
      # necessary for Jiak interaction.
      def params(opts={})
        jiak.bucket.params = opts
      end

      # :call-seq:
      #   JiakResource.schema  -> JiakSchema
      #
      # Get the schema for a resource.
      def schema
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.allowed(:f1,...,:fn)  -> JiakSchema
      #
      # Set the allowed fields for the schema of a resource.
      #
      # Returns the altered JiakSchema.
      def allowed(*fields)
        jiak.bucket.schema.allowed_fields = *fields
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.required(:f1,...,:fn)  -> JiakSchema
      #
      # Sets the required fields for the schema of a resource.
      #
      # Returns the altered JiakSchema.
      def required(*fields)
        jiak.bucket.schema.required_fields = *fields
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.readable(:f1,...,:fn)  -> JiakSchema
      #
      # Sets the readable fields for the schema of a resource.
      #
      # Returns the altered JiakSchema.
      def readable(*fields)
        jiak.bucket.schema.read_mask = *fields
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.writable(:f1,...,:fn)  -> JiakSchema
      #
      # Sets the writable fields for the schema of a resource.
      #
      # Returns the altered JiakSchema.
      def writable(*fields)
        jiak.bucket.schema.write_mask = *fields
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.activate  -> JiakSchema
      #
      # Prepare the Jiak server to accept JiakResource. Returns the schema set
      # on the Jiak server.
      def activate
        jiak.server.set_schema(jiak.bucket)
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.active?  -> true or false
      #
      # Determine if the Jiak server is prepared to accept data for this
      # JiakResource.
      def active?
        jiak.server.schema(jiak.bucket).eql? jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.keys   -> []
      #
      # Get an array of the current keys for this resource. Since key lists are
      # updated asynchronously on a Riak cluster the returned array can be out
      # of synch immediately after new puts or deletes.
      def keys
        jiak.server.keys(jiak.bucket)
      end

      # :call-seq:
      #   JiakResource.put(JiakResource,opts={})  -> JiakResource
      #
      # Put a JiakResource on the Jiak server. Valid options are:
      #
      # <code>:writes</code> :: The number of Riak nodes that must successfully store the data.
      # <code>:durable_writes</code> :: The number of Riak nodes (<code>< writes</code>) that must successfully store the data in a durable manner.
      # <code>:reads</code> :: The number of Riak nodes that must successfully read data being returned.
      # 
      # If any of the request parameters <code>:writes, :durable_writes,
      # :reads</code> are not set, each first defaults to the value set for the
      # JiakResource class, then to the value set on the Riak cluster. In
      # general the values set on the Riak cluster should suffice.
      def put(resource,opts={})
        opts[:object] = true
        resource.jiak = jiak.server.store(resource.jiak,opts)
        resource
      end

      # :call-seq:
      #   JiakResource.post(JiakResource,opts={})  -> JiakResource
      #
      # Put a JiakResource on the Jiak server with a guard to ensure the
      # resource has not been previously stored. See JiakResource#put for options.
      def post(resource,opts={})
        unless(resource.jiak.riak.nil?)
          raise JiakResourceException, "Resource already initially stored"
        end
        put(resource,opts)
      end

      # :call-seq:
      #   JiakResource.store(JiakResource,opts={})  -> JiakResource
      #
      # Updates a JiakResource on the Jiak server with a guard to ensure the
      # resource has been previously stored. See JiakResource#put for options.
      def store(resource,opts={})
        if(resource.jiak.riak.nil?)
          raise JiakResourceException, "Resource not previously stored"
        end
        put(resource,opts)
      end

      # :call-seq:
      #   JiakResource.get(key,opts={})  -> JiakResource
      #
      # Get a JiakResource on the Jiak server by the specified key. Valid
      # options are:
      #
      # <code>:reads</code> --- The number of Riak nodes that must successfully
      # reply with the data. If not set, defaults first to the value set for the
      # JiakResource class, then to the value set on the Riak cluster.
      def get(key,opts={})
        new(jiak.server.get(jiak.bucket,key,opts))
      end

      # :call-seq:
      #   JiakResource.get!(resource,opts={})  -> JiakResource
      #
      # Updates a JiakResource with the data on the Jiak server. The current
      # data of the JiakResource is overwritten, so use with caution. See
      # JiakResource.get for options.
      def get!(resource,opts={})
        resource.jiak = get(resource.jiak.key,opts).jiak
      end

      # :call-seq:
      #   JiakResource.delete(resource,opts={})  -> true or false
      #
      # Delete the JiakResource store on the Jiak server by the specified
      # key. Valid options are:
      #
      # <code>:waits</code> --- The number of Riak nodes that must reply the
      # delete has occurred before success. If not set, defaults first to the
      # value set for the JiakResource, then to the value set on the Riak
      # cluster. In general the values set on the Riak cluster should suffice.
      def delete(resource,opts={})
        jiak.server.delete(jiak.bucket,resource.jiak.key,opts)
      end

    end
    
    def self.included(including_class)    # :nodoc:
      including_class.instance_eval do
        extend ClassMethods
        def jiak  # :nodoc:
          @jiak
        end
        @jiak = Struct.new(:server,:uri,:name,:data,:bucket).new
      end
    end

    # def self.copy(klass)
    #   unless klass.include?(JiakResource)
    #     raise JiakResourceException, "expect a JiakResource class."
    #   end
    #   Class.new do
    #     include JiakResource
    #     self.server klass.jiak.server.uri
    #     self.resource :name => klass.jiak.bucket.name,
    #                  :data_class => klass.jiak.bucket.data_class
    #     end
    # end

    # ----------------------------------------------------------------------
    # Instance methods
    # ----------------------------------------------------------------------

    attr_accessor :jiak   # :nodoc:

    # :call-seq:
    #   JiakResource.new(*args)   -> JiakResource
    #
    # Create a JiakResource wrapping a JiakData instance. The argument array
    # is passed to the <code>new</code> method of the JiakData associated
    # with the JiakResource.
    def initialize(*args)
      # First form is used by JiakResource.get
      if(args.size == 1 && args[0].is_a?(JiakObject))
        @jiak = args[0]
      else
        bucket = self.class.jiak.bucket
        @jiak = JiakObject.new(:bucket => bucket,
                               :data => bucket.data_class.new(*args))
      end
    end

    # :call-seq:
    #   put(opts={})   -> nil
    #
    # Put this resource on the Jiak server. See JiakResource#ClassMethods#put
    # for options.
    def put(opts={})
      @jiak = (self.class.put(self,opts)).jiak
      self
    end

    # :call-seq:
    #   post(opts={})   -> nil
    #
    # Put this resource on the Jiak server with a guard to ensure the resource
    # has not been previously stored. See JiakResource#ClassMethods#put for
    # options.
    def post(opts={})
      @jiak = (self.class.post(self,opts)).jiak
      self
    end

    # :call-seq:
    #   store(opts={})   -> nil
    #
    # Put this resource on the Jiak server with a guard to ensure the resource
    # has been previously stored. See JiakResource#ClassMethods#put for
    # options.
    def store(opts={})
      @jiak = (self.class.store(self,opts)).jiak
      self
    end

    # :call-seq:
    #   get(opts={})   -> nil
    #
    # Get this resource from the Jiak server. The current data of the resource
    # is overwritten, so use with caution. See JiakResource#ClassMethods#get
    # for options.
    def get(opts={})
      self.class.get!(self,opts)
    end

    # :call-seq:
    #   delete(opts={})     ->  true or false
    #
    # Deletes the resource on the Jiak server. The local object is
    # uneffected. See JiakResource#ClassMethods#delete for options.
    def delete(opts={})
      self.class.delete(self,opts)
    end
  end
end
