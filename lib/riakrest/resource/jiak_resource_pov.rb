module RiakRest

  # JiakResourcePOV provides a point-of-view interface to existing JiakResource
  # data that restricts the fields available during Jiak interaction. This
  # restriction provides two primary benefits: Only explicitly declared fields
  # can be read or written via the POV, thereby protecting all other
  # JiakResource fields, and only the declared fields are transported to and
  # from the Jiak server, thereby reducing the HTTP message sizes.
  #
  # ===Example
  #  require 'riakrest'
  #  include RiakRest
  #
  #  class AB
  #    include JiakResource
  #    server SERVER_URI
  #    group  "test"
  #    attr_accessor :a, :b
  #    keygen { "k#{a}" }
  #  end
  #
  #  class A
  #    include JiakResourcePOV
  #    resource AB
  #    attr_accessor :a
  #  end
  #
  #  ab = AB.new(:a => 1, :b => 2)
  #  ab.post
  #  a = ab.pov(A)
  #  a.a = 11
  #  a.update
  #  
  #  ab.refresh
  #  ab.a                                     # => 11

  module JiakResourcePOV

    # ----------------------------------------------------------------------
    # Class methods
    # ----------------------------------------------------------------------
    
    # Class methods for creating a user-defined JiakResourcePOV.
    #
    # See JiakResourcePOV for example usage.
    module ClassMethods

      # :call-seq:
      #   JiakResourcePOV.resource(resource)
      #
      # Set the JiakResource to which this JiakResourcePOV is a point-of-view.
      def resource(resource)
        @resource = resource
        @jiak.bucket = JiakBucket.new(@resource.jiak.group,
                                      JiakDataFields.create)
      end

      # :call-seq:
      #   attr_reader :f1,...,:fn
      #
      # Add read accessible fields.
      def attr_reader(*fields)
        check_fields(fields,@resource.schema.read_mask)
        added_fields = @jiak.bucket.data_class.readable(*fields)
        added_fields.each do |field|
          class_eval <<-EOM
            def #{field}
              @jiak.object.data.#{field}
            end
          EOM
        end
        @jiak.read_mask = @jiak.bucket.data_class.schema.read_mask.join(',')
        nil
      end

      # :call-seq:
      #   attr_writer :f1,...,:fn
      #
      # Add write accessible fields.
      def attr_writer(*fields)
        check_fields(fields,@resource.schema.write_mask)
        added_fields = @jiak.bucket.data_class.writable(*fields)
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
        attr_reader(*fields)
        attr_writer(*fields)
      end

      def check_fields(fields,valid)
        invalid = fields.select {|f| !valid.include?(f)}
        unless(invalid.empty?)
          raise(JiakResourcePOVException,"invalid fields: #{invalid.inspect}")
        end
      end
      private :check_fields

      # :call-seq:
      #   JiakResourcePOV.keys   -> array
      #
      # Get an array of the current keys for this resource. Since key lists are
      # updated asynchronously on a Riak cluster the returned array can be out
      # of synch immediately after new puts or deletes.
      def keys
        @resource.jiak.client.keys(jiak.bucket)
      end

      # :call-seq:
      #   JiakResourcePOV.get(key,opts={})  -> JiakResourcePOV
      #
      # Get a JiakResourcePOV on the Jiak server by the specified key.
      #
      # =====Valid options:
      # <code>:reads</code> --- See JiakResource#get
      #
      # Raise JiakResourceNotFound if no resource exists on the Jiak server for
      # the key.
      def get(key,opts={})
        opts[:read] = @jiak.read_mask
        new(@resource.jiak.client.get(@jiak.bucket,key,opts))
      end

      # :call-seq:
      #   JiakResourcePOV.update(JiakResourcePOV,opts={})  -> JiakResourcePOV
      #
      # Updates a JiakResourcePOV on the Jiak server.
      #
      # See JiakResource#put for options.
      def update(resource,opts={})
        opts[:copy] = true
        opts[:read] = @jiak.read_mask
        @resource.put(resource,opts)
      end

      # :call-seq:
      #   JiakResourcePOV.refresh(resource,opts={})  -> JiakResourcePOV
      #
      # Updates a JiakResource with the data on the Jiak server. The current
      # data of the JiakResource is overwritten, so use with caution.
      #
      # See JiakResource#refresh for options.
      def refresh(resource,opts={})
        resource.jiak.object = get(resource.jiak.object.key,opts).jiak.object
      end

      # :call-seq:
      #   JiakResourcePOV.exist?(key) -> true or false
      #
      # Determine if a resource exists on the Jiak server for a key.
      def exist?(key)
        @resource.jiak.client.exist?(@jiak.bucket,key)
      end

      # :call-seq:
      #   JiakResourcePOV.do_auto_update(resource)  -> JiakResourcePOV or nil
      #
      # Determine if an auto update should be done on the resource and perform
      # an update if so.
      #
      # Public method as a by-product of implementation.
      def do_auto_update(rsrc)  # :no-doc:
        if(rsrc.auto_update? ||
            ((rsrc.auto_update? != false) && rsrc.class.auto_update?))
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

        @jiak = Struct.new(:bucket,:auto_update,:read_mask).new
        @jiak.auto_update = false
      end
    end

    # ----------------------------------------------------------------------
    # Instance methods
    # ----------------------------------------------------------------------

    attr_reader :jiak   # :nodoc:

    def initialize(jobj)    # :nodoc:
      unless(jobj.is_a?(JiakObject))
        # CxINC
        raise JiakException
      end
      @jiak = Struct.new(:object,:auto_update).new
      @jiak.object = jobj
      @jiak.auto_update = false
    end
    # CxINC
    # private_class_method :new

    # :call-seq:
    #   auto_update(true, false, or nil)
    #
    # See JiakResource#auto_update
    def auto_update=(state)
       unless (state.nil? || state.is_a?(TrueClass) || state.is_a?(FalseClass))
         raise JiakResource, "auto_update must be true, false, or nil"
       end
     @jiak.auto_update = state
    end
    
    # :call-seq:
    #   auto_update?  -> true, false, or nil
    #
    # See JiakResource#auto_update?
    def auto_update?
      @jiak.auto_update
    end

    # :call-seq:
    #   update(opts={})   -> nil
    #
    # Put this resource on the Jiak server. See JiakResource#ClassMethods#put
    # for options.
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
    #   jiak_resource == other -> true or false
    #
    # Equality -- Two JiakResourcePOVs are equal if they wrap the same Jiak
    # data.
    def ==(other)
      (@jiak.object == other.jiak.object)  rescue false
    end

    # :call-seq:
    #    eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a JiakResourcePOV
    # representing the same Jiak data.
    def eql?(other)
      other.is_a?(JiakResourcePOV) && @jiak.object.eql?(other.jiak.object)
    end
    
    def hash  # :nodoc:
      @jiak.object.hash
    end


  end
end
