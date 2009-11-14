module RiakRest
  # JiakResource provides a resource-oriented wrapper for Jiak interaction. See
  # RiakRest for a basic usage example.
  
  module JiakResource
    # ----------------------------------------------------------------------
    # Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for creating a user-defined JiakResource. The methods
    # <code>server</code>, <code>group</code> and <code>data_class</code> are
    # mandatory to create a fully usable JiakResource.
    #
    # ===Usage
    # <code>
    #   class Users
    #     include JiakResource
    #     server      'http://localhost:8002/jiak'
    #     jattr_accessor :login, :name
    #   end
    # </code>
    # 
    module ClassMethods

      # :call-seq:
      #   JiakServer.server(uri,opts={})
      #
      # Set the URI for Jiak server interaction. Go through a proxy if proxy
      # option specified.
      #
      # Valid options:
      #  <code>:proxy</code> Proxy server URI.
      def server(uri,opts={})
        jiak.server = JiakClient.new(uri,opts)
        jiak.uri = uri
      end

      # :call-seq:
      #   JiakResource.group(gname)
      #
      # Set the Jiak group name for the storage area of a resource.
      def group(gname)
        jiak.group = gname
        jiak.bucket.name = gname
      end

      def jattr_reader(*fields)
        check_fields(fields)
        added_fields = jiak.data.readable(*fields)
        added_fields.each do |field|
          define_method("#{field}") do
            @jiak.data.send("#{field}")
          end
        end
      end
      alias :jattr :jattr_reader

      def jattr_writer(*fields)
        check_fields(fields)
        added_fields = jiak.data.writable(*fields)
        added_fields.each do |field|
          define_method("#{field}=") do |val|
            @jiak.data.send("#{field}=",val)
            self.class.do_auto_update(self)
          end
        end
      end

      def jattr_accessor(*fields)
        jattr_reader *fields
        jattr_writer *fields
      end

      def check_fields(fields)
        if(fields.include?(:jiak) || fields.include?('jiak'))
          raise(JiakResourceException,
                "'jiak' reserved for RiakRest Resource usage")
        end
      end
      private :check_fields

      # :call-seq:
      #   JiakResource.params(opts={})  -> hash
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
      # individual call -> JiakResource -> Riak cluster. In general the values
      # set on the Riak cluster should suffice and these parameters aren't
      # necessary for Jiak interaction.
      def params(opts={})
        jiak.bucket.params = opts
      end

      # :call-seq:
      #   JiakResource.auto_post(state)  -> true or false
      #
      # Set <code>true</code> to have new instances of the resource auto-posted
      # to the Jiak server. Default is <code>false</code>.
      def auto_post(state)
        state = false  if state.nil?
        unless (state.is_a?(TrueClass) || state.is_a?(FalseClass))
          raise JiakResource, "auto_post must be true or false"
        end
        jiak.auto_post = state
      end

      # :call-seq:
      #   JiakResource.auto_post? -> true or false
      #
      # <code>true</code> if JiakResource is set to auto-post new instances.
      def auto_post?
        return jiak.auto_post
      end

      # :call-seq:
      #   JiakResource.auto_update(state)  -> true or false
      #
      # Set <code>true</code> to have changes to resource fields or links
      # trigger an auto-update to the Jiak server. Default is
      # <code>false</code>. Interacts with the instance-level resource
      # setting. See JiakResource#auto_update.
      def auto_update(state)
        state = false  if state.nil?
        unless (state.is_a?(TrueClass) || state.is_a?(FalseClass))
          raise JiakResource, "auto_update must be true or false"
        end
        jiak.auto_update = state
      end

      # :call-seq:
      #   JiakResource.auto_update? -> true or false
      #
      # <code>true</code> if JiakResource is set to auto-update.
      def auto_update?
        return jiak.auto_update
      end

      # :call-seq:
      #   JiakResource.schema  -> JiakSchema
      #
      # Get the schema for a resource.
      def schema
        jiak.data.schema
      end

      # :call-seq:
      #   JiakResource.keys   -> array
      #
      # Get an array of the current keys for this resource. Since key lists are
      # updated asynchronously on a Riak cluster the returned array can be out
      # of synch immediately after new puts or deletes.
      def keys
        jiak.server.keys(jiak.bucket)
      end

      # :call-seq:
      #   JiakResource.point_of_view  -> JiakSchema
      #
      # Ready the Jiak server point-of-view to accept structured interaction
      # with a JiakResource. Returns the schema set on the Jiak server.
      def point_of_view
        jiak.server.set_schema(jiak.bucket)
        jiak.bucket.schema
      end
      alias :pov :point_of_view

      # :call-seq:
      #   JiakResource.point_of_view?  -> true or false
      #
      # Determine if the point-of-view on the Jiak server is that of this
      # JiakResource.
      def point_of_view?
        jiak.server.schema(jiak.bucket).eql? jiak.bucket.schema
      end
      alias :pov? :point_of_view?

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
        opts[:return] = :object
        resource.jiak.object = jiak.server.store(resource.jiak.object,opts)
        resource.jiak_convenience
        resource
      end

      # :call-seq:
      #   JiakResource.post(JiakResource,opts={})  -> JiakResource
      #
      # Put a JiakResource on the Jiak server with a guard to ensure the
      # resource has not been previously stored. See JiakResource#put for
      # options.
      def post(resource,opts={})
        unless(resource.local?)
          raise JiakResourceException, "Resource already initially stored"
        end
        put(resource,opts)
      end

      # :call-seq:
      #   JiakResource.update(JiakResource,opts={})  -> JiakResource
      #
      # Updates a JiakResource on the Jiak server with a guard to ensure the
      # resource has been previously stored. See JiakResource#put for options.
      def update(resource,opts={})
        if(resource.local?)
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
      #
      # Raise JiakResourceNotFound if no resource exists on the Jiak server for
      # the key.
      def get(key,opts={})
        new(jiak.server.get(jiak.bucket,key,opts))
      end

      # :call-seq:
      #   JiakResource.refresh(resource,opts={})  -> JiakResource
      #
      # Updates a JiakResource with the data on the Jiak server. The current
      # data of the JiakResource is overwritten, so use with caution. See
      # JiakResource.get for options.
      def refresh(resource,opts={})
        resource.jiak.object = get(resource.jiak.key,opts).jiak.object
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
        jiak.server.delete(jiak.bucket,resource.jiak.object.key,opts)
      end

      # :call-seq:
      #   JiakResource.link(from,to,tag)  -> JiakResource
      #
      # Link from a resource to another resource by tag.
      #
      # Note the resource being linked to cannot be a local object since the
      # created link needs to include the Jiak server key. Even if a local
      # object has a local key intended for use as the Jiak server key, there
      # is no guarentee that key will not already be in use on the Jiak
      # server. Only after a resource is stored on the Jiak server is the key
      # assignment guarenteed.
      #
      # This restriction is not necessary for the resource being linked from,
      # since it's Jiak server key is not in play. This does allow for
      # establishing links to existing Jiak resources locally and storing with
      # the initial store of the local Jiak resource.
      def link(from,to,tag)
        if(to.local?)
          raise JiakResourceException, "Can't link to a local resource"
        end

        link = JiakLink.new(to.jiak.object.bucket, to.jiak.object.key, tag)
        unless from.jiak.object.links.include?(link)
          from.jiak.object.links << link
          do_auto_update(from)
        end
        from
      end

      # :call-seq:
      #   JiakResource.bi_link(rscr1,rscr2,tag1_2,tag2_1=nil)  -> JiakResource
      #
      # Link from rscr1 to rsrc2 using tag1_2 and from rscr2 to rsrc1 using
      # tag2_1. tag2_1 defaults to tag1_2 if nil.
      def bi_link(r1,r2,tag1_2,tag2_1=nil)
        tag2_1 ||= tag1_2
        link(r1,r2,tag1_2)
        link(r2,r1,tag2_1)
        r1
      end

      # :call-seq:
      #   JiakResource.remove_link(from,to,tag) -> true or false
      def remove_link(from,to,tag)
        link = JiakLink.new(to.jiak.object.bucket, to.jiak.object.key, tag)
        has_link = from.jiak.object.links.include?(link)
        if has_link
          from.jiak.object.links.delete(link)
          if(from.auto_update? ||
             ((from.auto_update? != false) && from.class.auto_update?))
            put(from)
          end
        end
        has_link
      end
      
      # :call-seq:
      #   JiakResource.query(from,*steps)
      #
      # Retrieves an array of JiakResource objects by starting with the links
      # in the <code>from</code> JiakResource and doing the query steps. The
      # steps are a series of query links designated by a JiakResource and a
      # string tag, or a JiakResource, a string tag and a string
      # accumulator. The type of JiakResource returned in the array is
      # determined by the JiakResource designated in the last step.
      #
      # ====Usage
      # <code>
      #   JiakResource.query(resource,Child,'child')
      #   JiakResource.query(resource,Parent,'odd',Child,'normal')
      # </code>
      def query(from,*steps)
        links = []
        until steps.empty?
          begin
            klass,tag = steps.shift(2)
            last_klass = klass
            acc = steps[0].is_a?(String) ? steps.shift : nil
            links << QueryLink.new(klass.jiak.group,tag,acc)
          rescue
            raise(JiakResourceException, 
                  "each step should be Klass,tag or Klass,tag,acc")
          end
        end
        links = links[0]  if links.size == 1
        jiak.server.walk(from.jiak.object.bucket, from.jiak.object.key, links,
                         last_klass.jiak.bucket.data_class).map do |jobj|
          last_klass.new(jobj)
        end        
      end
      alias :walk :query
      
      # :call-seq:
      #   JiakResource.exist?(key) -> true or false
      #
      # Determine if a resource exists on the Jiak server for a key.
      def exist?(key)
        begin
          get(key)
          true
        rescue JiakResourceNotFound
          false
        end
      end

      # :call-seq:
      #   JiakResource.do_auto_update(resource)  -> JiakResource or nil
      #
      # Determine if an auto update should be done on the resource and perform
      # an update if so.
      #
      # Public method as a by-product of implementation.
      def do_auto_update(rsrc)  # :no-doc:
        if(!rsrc.local? &&
           (rsrc.auto_update? ||
            ((rsrc.auto_update? != false) && rsrc.class.auto_update?)))
          update(rsrc)
        end
      end

    end
    
    def self.included(including_class)    # :nodoc:
      including_class.instance_eval do
        extend ClassMethods
        def jiak  # :nodoc:
          @jiak
        end
        @jiak = Struct.new(:server,:uri,:group,:data,:bucket,
                           :auto_post,:auto_update).new
        @jiak.data = JiakDataHash.create
        @jiak.group = self.name.split('::').last.downcase
        @jiak.bucket = JiakBucket.new(@jiak.group,@jiak.data)
        
        @jiak.auto_post = false
        @jiak.auto_update = false
      end
    end

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
      # First form is used by JiakResource.get and JiakResource.query
      @jiak = Struct.new(:object,:bucket,:key,:data,:links,:auto_update).new
      if(args.size == 1 && args[0].is_a?(JiakObject))
        @jiak.object = args[0]
      else
        bucket = self.class.jiak.bucket
        @jiak.object = JiakObject.new(:bucket => bucket,
                                      :data => bucket.data_class.new(*args))
        if(self.class.auto_post?)
          if(!@jiak.object.key.empty? && self.class.exist?(@jiak.object.key))
            raise(JiakResourceException,
                  "auto-post failed: key='#{@jiak.object.key}' already exists.")
          end
          self.class.post(self)
        end
      end
      jiak_convenience
    end

    # Public method as a by-product of implementation. No harm done in calling
    # this method, as it will just repeat assignments already done.
    def jiak_convenience     # :nodoc:
      @jiak.bucket = @jiak.object.bucket
      @jiak.key    = @jiak.object.key
      @jiak.data   = @jiak.object.data
      @jiak.links  = @jiak.object.links
    end

    # :call-seq:
    #   auto_update(true, false, or nil)
    #
    # Set to <code>true</code> to have any changes to the fields or links of
    # a resource trigger an auto-update to the Jiak server. Default is
    # <code>nil</code>.
    #
    # The setting here interacts with the class level setting
    # JiakResource#ClassMethods#auto_update in the following manner:
    # <code>true</code>  :: Auto-update regardless of class setting.
    # <code>false</code> :: No auto-update, regardless of class setting.
    # <code>nil</code>   :: Defer to the class setting.
    def auto_update=(state)
       unless (state.nil? || state.is_a?(TrueClass) || state.is_a?(FalseClass))
         raise JiakResource, "auto_update must be true, false, or nil"
       end
     @jiak.auto_update = state
    end

    # :call-seq:
    #   auto_update?  -> true, false, or nil
    #
    # Get current auto_update setting. See JiakResource#auto_update for settings.
    def auto_update?
      @jiak.auto_update
    end

    # :call-seq:
    #   put(opts={})   -> nil
    #
    # Put this resource on the Jiak server. See JiakResource#ClassMethods#put
    # for options.
    def put(opts={})
      @jiak.object = (self.class.put(self,opts)).jiak.object
      jiak_convenience
      self
    end

    # :call-seq:
    #   post(opts={})   -> nil
    #
    # Put this resource on the Jiak server with a guard to ensure the resource
    # has not been previously stored. See JiakResource#ClassMethods#put for
    # options.
    def post(opts={})
      @jiak.object = (self.class.post(self,opts)).jiak.object
      jiak_convenience
      self
    end

    # :call-seq:
    #   update(opts={})   -> nil
    #
    # Put this resource on the Jiak server with a guard to ensure the resource
    # has been previously stored. See JiakResource#ClassMethods#put for
    # options.
    def update(opts={})
      @jiak.object = (self.class.update(self,opts)).jiak.object
      jiak_convenience
      self
    end
    alias :push :update

    # :call-seq:
    #   refresh(opts={})   -> nil
    #
    # Get this resource from the Jiak server. The current data of the resource
    # is overwritten, so use with caution. See JiakResource#ClassMethods#get
    # for options.
    def refresh(opts={})
      self.class.refresh(self,opts)
    end
    alias :pull :refresh

    # :call-seq:
    #   local? -> true or false
    #
    # <code>true</code> if a resource is local only, i.e., has not been
    # post/put to the Jiak server. This test is used in the guards for class
    # and instance level post/update methods.
    def local?
      jiak.object.local?
    end

    # :call-seq:
    #   delete(opts={})     ->  true or false
    #
    # Delete the resource on the Jiak server. The local object is
    # uneffected. See JiakResource#ClassMethods#delete for options.
    def delete(opts={})
      self.class.delete(self,opts)
    end

    # :call-seq:
    #   link(resource,tag) -> JiakResource
    #
    # Link to the resource by tag. Note the resource being linked to cannot be
    # local. The object creating this link can be local. See JiakResource#link
    # for a discussion.
    def link(resource,tag)
      self.class.link(self,resource,tag)
    end

    # :call-seq:
    #   bi_link(resource,tag,reverse_tag=nil) -> JiakResource
    #
    # Link to a resource by tag and back to this resource by reverse_tag. The
    # value of the reverse_tag defaults to tag.
    def bi_link(resource,tag,reverse_tag=nil)
      self.class.bi_link(self,resource,tag,reverse_tag)
    end

    # :call-seq:
    #   remove_link(resource,tag) -> true or false
    #
    # Remove tagged link to resource.
    def remove_link(resource,tag)
      self.class.remove_link(self,resource,tag)
    end

    # :call-seq:
    #   query(*steps) -> array
    #
    # Performs a Jiak query starting at this resource. See
    # JiakResource#ClassMethods#query for description.
    #
    # ====Usage
    # <code>
    #   query(Child,'child')
    #   query(Parent,'odd',Child,'normal')
    # </code>
    def query(*steps)
      self.class.query(self,*steps)
    end
    alias :walk :query

    # :call-seq:
    #   jiak_resource == other -> true or false
    #
    # Equality -- Two JiakResources are equal if they wrap the same data.
    def ==(other)
      (@jiak.object == other.jiak.object)  rescue false
    end

    # :call-seq:
    #    eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a JiakResource
    # representing the same Jiak data.
    def eql?(other)
      other.is_a?(JiakResource) && @jiak.object.eql?(other.jiak.object)
    end
    
    def hash  # :nodoc:
      @jiak.object.hash
    end

  end
end
