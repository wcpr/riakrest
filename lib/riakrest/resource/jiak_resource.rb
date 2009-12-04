module RiakRest
  # JiakResource provides a resource-oriented wrapper for Jiak interaction.
  #
  # ===Example
  #  require 'riakrest'
  #  include RiakRest
  #
  #  class People
  #    include JiakResource
  #    server 'http://localhost:8002/jiak'
  #    attr_accessor :name, :age
  #    auto_manage
  #  end
  #
  #  remy = People.new(:name => 'Remy',:age => 10)       # (auto-post)
  #  remy.age = 11                                       # (auto-update)
  #
  #  callie = People.new(:name => 'Callie', :age => 13)
  #  remy.link(callie,'sister')
  #
  #  sisters = remy.query(People,'sister')
  #  sisters[0].eql?(callie)                             # => true
  #
  #  remy.delete
  #  callie.delete
  
  module JiakResource

    PUT_PARAMS    = [:writes,:durable_writes,:reads,:copy,:read]
    GET_PARAMS    = [:reads,:read]
    DELETE_PARAMS = [:deletes]

    PUT_PARAMS.freeze
    GET_PARAMS.freeze
    DELETE_PARAMS.freeze

    # ----------------------------------------------------------------------
    # Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for creating a user-defined JiakResource.
    #
    # See JiakResource for example usage.
    module ClassMethods

      # :call-seq:
      #   JiakResource.server(uri,opts={})
      #
      # Set the URI for Jiak server interaction. Go through a proxy if proxy
      # option specified.
      #
      # =====Valid options:
      #  <code>:proxy</code> -- Proxy server URI.
      def server(uri,opts={})
        jiak.client = JiakClient.new(uri,opts)
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

      # :call-seq:
      #   attr_reader :f1,...,:fn
      #
      # Add read accessible fields.
      def attr_reader(*fields)
        check_fields(fields)
        added_fields = jiak.data.readable(*fields)
        added_fields.each do |field|
          class_eval <<-EOM
            def #{field}
              @jiak.object.data.#{field}
            end
          EOM
        end
        nil
      end
      alias :attr :attr_reader

      # :call-seq:
      #   attr_writer :f1,...,:fn
      #
      # Add write accessible fields.
      def attr_writer(*fields)
        check_fields(fields)
        added_fields = jiak.data.writable(*fields)
        added_fields.each do |field|
          class_eval <<-EOM
            def #{field}=(val)
              @jiak.object.data.#{field} = val
              self.class.do_auto_update(self)
            end
          EOM
        end
        nil
      end

      # :call-seq:
      #   attr_accessor :f1,...,:fn
      #
      # Add read/write accessible fields.
      def attr_accessor(*fields)
        attr_reader *fields
        attr_writer *fields
      end

      def check_fields(fields)
        if(fields.include?(:jiak) || fields.include?('jiak'))
          raise(JiakResourceException,
                "'jiak' reserved for RiakRest Resource usage")
        end
      end
      private :check_fields

      # :call-seq:
      #   keygen(&block)
      #
      # Specify the block for generating keys for a JiakResource instance.
      def keygen(&block)
        jiak.data.class_eval <<-EOS
          define_method(:keygen,&block)
        EOS
      end

      # :call-seq:
      #   JiakResource.params(opts={})  -> hash
      #
      # Default options for request parameters during Jiak interaction.
      #
      # =====Valid options
      # <code>:reads</code>:: Minimum number of responding nodes for successful reads.
      # <code>:writes</code>:: Minimum number of responding nodes for successful writes. Writes can be buffered for performance.
      # <code>:durable_writes</code>:: Minimum number of responding nodes that must perform a durable write to a persistence layer.
      # <code>:deletes</code>:: Minimum number of responding nodes for successful delete.
      #
      # The configuration of a Riak cluster includes server setting for
      # <code>writes, durable_writes, reads,</code> and <code>deletes</code>
      # parameters. None of these parameter are required by RiakRest, and their
      # use within RiakRest is to override the Riak cluster settings, either at
      # the JiakResource level or the individual request level.
      #
      # Settings passed to individual <code>get, put, post, update,
      # refresh,</code> and <code>delete</code> requests take precendence over
      # the setting maintained by a JiakResource. Any parameter not set in
      # JiakResource or on an individual request will default to the values
      # set in the Riak cluster.
      def params(opts={})
        jiak.client.params = opts
      end

      # :call-seq:
      #   JiakResource.auto_post(state)  -> true or false
      #
      # Set <code>true</code> to have new instances of the resource auto-posted
      # to the Jiak server.
      #
      # Default value for state is <code>true</code>. Note the default behavior
      # for JiakResource is auto-post false.
      def auto_post(state=true)
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
      # trigger an auto-update to the Jiak server. Interacts with the
      # instance-level resource setting. See JiakResource#auto_update.
      #
      # Default value for state is <code>true</code>. Note the default behavior
      # for JiakResource is auto-update false.
      def auto_update(state=true)
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
      #   JiakResource.auto_manage(state)  -> true or false
      #
      # Set auto-post and auto-manage simultaneously.
      def auto_manage(state=true)
        auto_post state
        auto_update state
      end

      # :call-seq:
      #   JiakResource.auto_update? -> true or false
      #
      # <code>true</code> if JiakResource is set to auto-update.
      def auto_manage?
        return auto_post? && auto_update?
      end

      # :call-seq:
      #   JiakResource.schema  -> JiakSchema
      #
      # Get the schema for a resource.
      def schema
        jiak.data.schema
      end

      # :call-seq:
      #   JiakResource.push_schema  -> nil
      #
      # Push schema to the Jiak server. If no schema is provided, pushes the
      # schema associated with the JiakResource.
      def push_schema(schema=nil)
        schema ||= jiak.bucket.schema
        jiak.client.set_schema(jiak.bucket.name,schema)
      end

      # :call-seq:
      #   JiakResource.server_schema?  -> true or false
      #
      # Determine if a schema is that set on the Jiak server. If no schema is
      # provided, use the schema associated with the JiakResource.
      def server_schema?(schema=nil)
        schema ||= jiak.bucket.schema
        jiak.client.schema(jiak.bucket).eql? schema
      end

      # :call-seq:
      #   JiakResource.keys   -> array
      #
      # Get an array of the current keys for this resource. Since key lists are
      # updated asynchronously on a Riak cluster the returned array can be out
      # of synch immediately after new puts or deletes.
      def keys
        jiak.client.keys(jiak.bucket)
      end

      # :call-seq:
      #   JiakResource.put(JiakResource,opts={})  -> JiakResource
      #
      # Put a JiakResource on the Jiak server.
      #
      # =====Valid options:
      # <code>:writes</code>
      # <code>:durable_writes</code>
      # <code>:reads</code>
      # 
      # See JiakResource#params for description of options.
      def put(resource,opts={})
        check_opts(opts,PUT_PARAMS,JiakResourceException)
        opts[:return] = :object
        resource.jiak.object = jiak.client.store(resource.jiak.object,opts)
        resource
      end

      # :call-seq:
      #   JiakResource.post(JiakResource,opts={})  -> JiakResource
      #
      # Put a JiakResource on the Jiak server with a guard to ensure the
      # resource has not been previously stored.
      #
      # See JiakResource#put for options.
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
      # resource has been previously stored.
      #
      # See JiakResource#put for options.
      def update(resource,opts={})
        if(resource.local?)
          raise JiakResourceException, "Resource not previously stored"
        end
        put(resource,opts)
      end

      # :call-seq:
      #   JiakResource.get(key,opts={})  -> JiakResource
      #
      # Get a JiakResource on the Jiak server by the specified key.
      #
      # =====Valid options:
      # <code>:reads</code> --- See JiakResource#params
      #
      # Raise JiakResourceNotFound if no resource exists on the Jiak server for
      # the key.
      def get(key,opts={})
        check_opts(opts,GET_PARAMS,JiakResourceException)
        new(jiak.client.get(jiak.bucket,key,opts))
      end

      # :call-seq:
      #   JiakResource.refresh(resource,opts={})  -> JiakResource
      #
      # Updates a JiakResource with the data on the Jiak server. The current
      # data of the JiakResource is overwritten, so use with caution.
      #
      # See JiakResource#get for options.
      def refresh(resource,opts={})
        check_opts(opts,GET_PARAMS,JiakResourceException)
        resource.jiak.object = get(resource.jiak.object.key,opts).jiak.object
      end

      # :call-seq:
      #   JiakResource.delete(resource,opts={})  -> true or false
      #
      # Delete the JiakResource store on the Jiak server by the specified
      # key.
      #
      # =====Valid options:
      # <code>:deletes</code> --- See JiakResource#params
      def delete(resource,opts={})
        check_opts(opts,DELETE_PARAMS,JiakResourceException)
        jiak.client.delete(jiak.bucket,resource.jiak.object.key,opts)
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
      #   JiakResource.query(from,steps,opts={})
      #
      # Retrieves an array of JiakResource objects by starting with the links
      # in the <code>from</code> JiakResource and performing the query
      # steps. Steps is an array holding a series of query links designated by
      # JiakResource,tag pairs. The type of JiakResources returned by the query
      # is determined by the JiakResource class designated in the last step.
      #
      # Note: Although Jiak supports accumulating intermediate link step
      # results, since RiakRest auto-inflates returned data intermediate
      # accumulation is not supported. The most common usage, however, is to
      # only accumulate the last step as supported by RiakRest.
      #
      # ====Usage
      # <code>
      #   JiakResource.query(resource,[Child,'child'])
      #   JiakResource.query(resource,[Parent,'odd',Child,'normal'])
      # </code>
      def query(from,steps,opts={})
        check_opts(opts,GET_PARAMS,JiakResourceException)
        begin
          links = []
          klass = nil
          steps.each_slice(2) do |pair|
            klass = pair[0]
            links << QueryLink.new(klass.jiak.bucket.name,pair[1],nil)
          end
          data_class = klass.jiak.bucket.data_class
          if(klass.include?(JiakResourcePOV))
            opts[:read] = klass.jiak.read_mask
          end
          jiak.client.walk(from.jiak.object.bucket,
                           from.jiak.object.key,
                           links,
                           data_class,
                           opts).map {|jobj| klass.new(jobj)}
        # rescue
        #   raise(JiakResourceException,
        #         "each step should be JiakResource,tag pair")
        end
      end
      alias :walk :query
      
      # :call-seq:
      #   JiakResource.exist?(key) -> true or false
      #
      # Determine if a resource exists on the Jiak server for a key.
      def exist?(key)
        jiak.client.exist?(jiak.bucket,key)
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
        @jiak = Struct.new(:client,:uri,:group,:data,:bucket,
                           :auto_post,:auto_update).new
        @jiak.data = JiakDataFields.create
        @jiak.group = self.name.split('::').last.downcase
        @jiak.bucket = JiakBucket.new(@jiak.group,@jiak.data)
        
        @jiak.auto_post = false
        @jiak.auto_update = false
      end
    end

    # ----------------------------------------------------------------------
    # Instance methods
    # ----------------------------------------------------------------------

    attr_reader :jiak   # :nodoc:

    # :call-seq:
    #   JiakResource.new(*args)   -> JiakResource
    #
    # Create a JiakResource wrapping a JiakData instance. The argument array
    # is passed to the <code>new</code> method of the JiakData associated
    # with the JiakResource.
    def initialize(*args)
      # First form is used by JiakResource.get and JiakResource.query
      @jiak = Struct.new(:object,:auto_update).new
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
    # Get current auto_update setting. See JiakResource#auto_update for
    # settings.
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
    #   query(steps) -> array
    #
    # Performs a Jiak query starting at this resource. See
    # JiakResource#ClassMethods#query for description.
    #
    # ====Usage
    # <code>
    #   query([Child,'child'])
    #   query([Parent,'odd',Child,'normal'])
    # </code>
    def query(steps,opts={})
      self.class.query(self,steps)
    end
    alias :walk :query

    # CxINC
    def pov(pov)
      pov.get(@jiak.object.key)
    end
    
    # :call-seq:
    #   jiak_resource == other -> true or false
    #
    # Equality -- Two JiakResources are equal if they wrap the same Jiak data.
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
