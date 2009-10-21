module RiakRest
  module JiakResource

    # :stopdoc:
    #
    # CxINC How to handle options to store,get,delete ?
    #
    # :startdoc:

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
      # <code>data_class<code>:: data class for the resource. <em>Mandatory</em>
      # <code>name<code>:: Jiak bucket name for this resource. <em>Optional</em>
      #
      # For each field in the <code>allowed_fields</code> array of the
      # JiakSchema for the data class a instance method is added for instances
      # of this resource. These instance methods allow easy access to getting
      # and setting the data values wrapped by a JiakResource.
      def resource(opts={})
        unless opts[:data_class]
          raise JiakResourceException, ":data_class required."
        end
        name = opts[:name] || opts[:data_class].to_s.split(/::/).last
        jiak.bucket = JiakBucket.create(name,opts[:data_class])
        jiak.client.set_schema(jiak.bucket)
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
      #   JiakResource.keys   -> []
      #
      # Get an array of the current keys for this resource. Since key lists are
      # updated asynchronously on the Riak cluster fronted by the Jiak server
      # the returned array can be out of synch.
      def keys
        jiak.client.keys(jiak.bucket)
      end

      # :call-seq:
      #   JiakResource.store(JiakResource)  -> JiakResource
      #
      # Stores a JiakResource on the Jiak server.
      def store(resource)
        jiak.client.store(resource.jiak,
                          {JiakClient::RETURN_BODY => true})
      end

      # :call-seq:
      #   JiakResource.store!(JiakResource)  -> JiakResource
      #
      # Stores a JiakResource on the Jiak server with a guard to ensure the
      # resource has not been previously stored. Provides initial create semantics.
      def store!(resource)
        unless(resource.jiak.riak.nil?)
          raise JiakResourceException, "Resource already initially stored"
        end
        store(resource)
      end

      # :call-seq:
      #   JiakResource.update(JiakResource)  -> JiakResource
      #
      # Updates a JiakResource on the Jiak server with a guard to ensure the
      # resource has been previously stored.
      def update(resource)
        if(resource.jiak.riak.nil?)
          raise JiakResourceException, "Resource not previously stored"
        end
        store(resource)
      end

      # :call-seq:
      #   JiakResource.get(key)  -> JiakResource
      #
      # Get the JiakResource store on the Jiak server by the specified key in
      # the JiakResource bucket.
      def get(key)
        new(jiak.client.get(jiak.bucket,key))
        # create(jiak.client.get(jiak.bucket,key))
      end

      # :call-seq:
      #   JiakResource.refresh!(resource)  -> JiakResource
      #
      # Updates a JiakResource with the data on the Jiak server. The current
      # data of the JiakResource is overwritten, so use with caution.
      def refresh!(resource)
        resource.jiak = get(resource.jiak.key).jiak
      end

      # :call-seq:
      #   JiakResource.delete(resource)  -> ???
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
    #   resource.store  -> nil
    #
    # Stores this resource on the Jiak server.
    def store
      @jiak = self.class.store(self)
    end

    # :call-seq:
    #   resource.store!   -> nil
    #
    # Stores this resource on the Jiak server with a guard to ensure the
    # resource has not been previously stored. Provides initial create sematics.
    def store!
      @jiak = self.class.store!(self)
    end

    # :call-seq:
    #   resource.update   -> nil
    #
    # Updates this resource on the Jiak server with a guard to ensure the
    # resource has been previously stored.
    def update
      @jiak = self.class.update(self)
    end

    # :call-seq:
    #   resource.refresh!   -> nil
    #
    # Updates this resource with the data on the Jiak server. The current data
    # of the resource is overwritten, so use with caution.
    def refresh!
      self.class.refresh!(self)
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
