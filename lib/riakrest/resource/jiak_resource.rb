module RiakRest
  module JiakResource

    # CxINC How to handle options to store,get,delete ?

    # ----------------------------------------------------------------------
    # Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for use in creating a user-defined JiakResource. The
    # methods <code>server</code> and <code>resource</code> are mandatory.
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
      #   server server_uri
      #
      # Set the URI for the server on which this resource is maintained.
      #
      def server(server_uri)
        jiak.client = JiakClient.create(server_uri)
      end

      # :call-seq:
      #   resource options
      #
      # Valid options are:
      # <code>data_class</code> :: data class for the resource.
      # <code>name</code> :: Jiak bucket name for the resource.
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
      def resource(opts={})
        unless opts[:data_class]
          raise JiakResourceException, "data_class required."
        end
        unless opts[:data_class].include?(JiakData)
          raise JiakResourceException, "data_class must include module JiakData"
        end

        name = opts[:name] || opts[:data_class].to_s.split(/::/).last

        jiak.bucket = JiakBucket.create(name,opts[:data_class])
        jiak.client.set_schema(jiak.bucket) if opts[:activate] 

        opts[:data_class].allowed_fields.each do |field|
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
      #   JiakResource.create(*args)   -> JiakResource
      #
      # Create a JiakResource wrapping a JiakData instance created with the
      # passed arguments.
      def create(*args)
        new(*args)
      end

      # :call-seq:
      #   JiakResource.server_uri  -> string
      #
      #   Get the URI for the server maintaining the resource.
      def server_uri
        jiak.client.server_uri
      end

      # :call-seq:
      #   JiakResource.schema  -> JiakSchema
      #
      # Gets the schema for the data class of this resource.
      def schema
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.activate  -> JiakSchema
      #
      # Prepare the Jiak server to accept JiakResource data.
      def activate
        jiak.client.set_schema(jiak.bucket)
        jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.active?  -> <code>true / false</code>
      #
      # Determine if the Jiak server is prepared to accept data for this
      # JiakResource.
      def active?
        jiak.client.schema(jiak.bucket).eql? jiak.bucket.schema
      end

      # :call-seq:
      #   JiakResource.keys   -> []
      #
      # Get an array of the current keys for this resource. Since key lists are
      # updated asynchronously on the Riak cluster fronted by the Jiak server
      # the returned array can be out of synch.
      def keys
        jiak.client.keys(jiak.bucket)
      end

      # :call-seq:
      #   JiakResource.put(JiakResource)  -> JiakResource
      #
      # Put a JiakResource on the Jiak server.
      def put(resource)
        jiak.client.store(resource.jiak,
                          {JiakClient::RETURN_BODY => true})
      end

      # :call-seq:
      #   JiakResource.post(JiakResource)  -> JiakResource
      #
      # Put a JiakResource on the Jiak server with a guard to ensure the
      # resource has not been previously stored.
      def post(resource)
        unless(resource.jiak.riak.nil?)
          raise JiakResourceException, "Resource already initially stored"
        end
        put(resource)
      end

      # :call-seq:
      #   JiakResource.store(JiakResource)  -> JiakResource
      #
      # Updates a JiakResource on the Jiak server with a guard to ensure the
      # resource has been previously stored.
      def store(resource)
        if(resource.jiak.riak.nil?)
          raise JiakResourceException, "Resource not previously stored"
        end
        put(resource)
      end

      # :call-seq:
      #   JiakResource.get(key)  -> JiakResource
      #
      # Get the JiakResource on the Jiak server by the specified key in the
      # JiakResource bucket.
      def get(key)
        new(jiak.client.get(jiak.bucket,key))
      end

      # :call-seq:
      #   JiakResource.get!(resource)  -> JiakResource
      #
      # Updates a JiakResource with the data on the Jiak server. The current
      # data of the JiakResource is overwritten, so use with caution.
      def get!(resource)
        resource.jiak = get(resource.jiak.key).jiak
      end

      # :call-seq:
      #   JiakResource.delete(resource)  -> <code>true</code>/<code>false</code>
      #
      # Delete the JiakResource store on the Jiak server by the specified key
      # in the JiakResource bucket.
      def delete(resource)
        jiak.client.delete(jiak.bucket,resource.jiak.key)
      end

    end
    
    def self.included(including_class)    # :nodoc:
      including_class.instance_eval do
        extend ClassMethods
        private_class_method :new
        def jiak
          @jiak
        end
        @jiak = Struct.new(:client,:bucket).new
      end
    end

    # ----------------------------------------------------------------------
    # Instance methods
    # ----------------------------------------------------------------------

    attr_accessor :jiak

    # First form is used by the JiakResource.get; the second form is used by
    # JiakResource.create.
    def initialize(*args)   # :nodoc:
      if(args.size == 1 && args[0].is_a?(JiakObject))
        @jiak = args[0]
      else
        bucket = self.class.jiak.bucket
        @jiak = JiakObject.create(:bucket => bucket,
                                  :data => bucket.data_class.create(*args))
      end
    end

    # :call-seq:
    #   resource.put   -> nil
    #
    # Put this resource on the Jiak server.
    def put
      @jiak = self.class.put(self)
    end

    # :call-seq:
    #   resource.post   -> nil
    #
    # Put this resource on the Jiak server with a guard to ensure the resource
    # has not been previously stored.
    def post
      @jiak = self.class.post(self)
    end

    # :call-seq:
    #   resource.store   -> nil
    #
    # Put this resource on the Jiak server with a guard to ensure the resource
    # has been previously stored.
    def store
      @jiak = self.class.store(self)
    end

    # :call-seq:
    #   resource.get   -> nil
    #
    # Get this resource from the Jiak server. The current data of the resource
    # is overwritten, so use with caution.
    def get
      self.class.get!(self)
    end

    # :call-seq:
    #   resource.delete     -> <code>true</code> or <code>false</code>
    #
    # Deletes the resource on the Jiak server. The local object is uneffected.
    def delete
      self.class.delete(self)
    end
  end
end
