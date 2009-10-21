module RiakRest

  # Top-level RiakRest exception. All RiakRest exceptions are subclass of this
  # class.
  class Exception < StandardError
  end

  # Client exception in accessing a resource on the Jiak server.
  class JiakClientException < RiakRest::Exception
    attr_accessor :params
    
    # call-seq:
    #    raise JiakClientException, message="", params={}
    #
    # The message is handled using normal Ruby exception handling. The params
    # field is a hash containing:
    # <code>action</code>:: The client resource access action.
    # <code>args</code>:: The arguments to the action.
    # <code>uri</code>:: The URI used to access the resource.
    def initialize(msg="", params={})
      super(msg)
      @params = params
    end

    # call-seq:
    #    err.description -> string
    #
    # A string description of a client error when accessing a Jiak resource.
    def description
      unless(@params.empty?)
        action = @params[:action] || ""
        args = @params[:args] || "()"
        uri = @params[:uri] || ""
        "#{self.class}: #{action}#{args} #{message} using uri='#{uri}'"
      else
        "#{self.class}: #{message}"
      end
    end
  end

  # Exceptions pertaining to JiakClient usage.
  class JiakResourceException < RiakRest::Exception
  end

  # Resource not found on the Jiak server.
  class JiakResourceNotFound < RiakRest::JiakResourceException
  end

  # Exceptions pertaining to JiakBucket usage.
  class JiakBucketException < RiakRest::Exception
  end

  # Exceptions pertaining to JiakObject usage.
  class JiakObjectException < RiakRest::Exception
  end

  # Exceptions pertaining to JiakData usage.
  class JiakDataException < RiakRest::Exception
  end

  # Exceptions pertaining to JiakLink usage.
  class JiakLinkException < RiakRest::Exception
  end

  # Exceptions pertaining to JiakSchema usage.
  class JiakSchemaException < RiakRest::Exception
  end


end
