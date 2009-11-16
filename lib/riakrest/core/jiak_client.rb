module RiakRest

  # Restful client interaction with a Riak document store via the HTTP/JSON
  # interface Jiak.
  #
  # ===Example
  #  require 'riakrest'
  #  include RiakRest
  #
  #  class People
  #    include JiakData
  #    jattr_accessor :name, :age
  #  end
  #
  #  client = JiakClient.new("http://localhost:8002/jiak")
  #  bucket = JiakBucket.new('people',People)
  #  client.set_schema(bucket)
  #
  #  remy = client.store(JiakObject.new(:bucket => bucket,
  #                                      :data => People.new(:name => "remy",
  #                                                          :age => 10)),
  #                       :return => :object)
  #  callie = client.store(JiakObject.new(:bucket => bucket,
  #                                       :data => People.new(:name => "Callie",
  #                                                           :age => 12)),
  #                        :return => :object)
  #
  #  remy.data.name = "Remy"
  #  remy << JiakLink.new(bucket,callie.key,'sister')
  #  client.store(remy)
  #
  #  sisters = client.walk(bucket,remy.key,
  #                        QueryLink.new(bucket,'sister'),People)
  #  sisters[0].eql?(callie)                                       #  => true
  #
  #  client.delete(bucket,remy.key)
  #  client.delete(bucket,callie.key)
  #
  # See JiakResource for the same example using the RiakRest Resource layer.
  class JiakClient

    attr_accessor :server, :proxy, :params

    # :stopdoc:
    APP_JSON       = 'application/json'
    RETURN_BODY    = 'returnbody'
    READS          = 'r'
    WRITES         = 'w'
    DURABLE_WRITES = 'dw'
    RESPONSE_WAITS = 'rw'
    KEYS           = 'keys'
    SCHEMA         = 'schema'
    VALID_PARAMS   = [:reads,:writes,:durable_writes,:waits]
    VALID_OPTS     = VALID_PARAMS << :proxy
    # :startdoc:

    # :call-seq:
    #   JiakClient.new(uri,opts={})  -> uri
    #
    # Create a new client for Riak RESTful (Jiak) interaction with the server at
    # the specified URI. Go through a proxy if proxy option specified.
    #
    # =====Valid options
    # <code>:reads</code>:: Respond after this many Riak nodes reply to a read request.
    # <code>:writes</code>:: Respond after this many Riak nodes reply to a write request.
    # <code>:durable_writes</code>:: Ensure this many Riak nodes perform a durable write.
    # <code>:waits</code>:: Respond after this many Riak nodes reply to a delete request.
    # <code>:proxy</code>:: Proxy server URI
    #
    # Any of the request parameters <code>writes, durable_writes, reads,</code>
    # and <code>waits</code> can be set on a per request basis. If the
    # parameters are not specified, the value set for JiakClient is used. If
    # neither of those scopes include the parameter, the value set on the Riak
    # cluster is used.
    # 
    def initialize(uri, opts={})
      check_opts(opts,VALID_OPTS,JiakClientException)
      self.server = uri
      self.proxy = opts.delete(:proxy)
      self.params = opts
    end

    # :call-seq:
    #   server = uri
    #
    # Set the Jiak server URI for the client.
    #
    # Raise JiakClientException if server URI is not string.
    def server=(uri)
      unless uri.is_a?(String)
        raise JiakClientException, "Jiak server URI should be a string."
      end
      @server = uri
      @server += '/' unless @server.end_with?('/')
      @server
    end

    # :call-seq:
    #
    #   server  -> string
    #
    # Return Jiak server URI
    def server
      @server
    end

    # :call-seq:
    #   proxy = uri
    #
    # Set Jiak interaction to go through a proxy.
    #
    # Raise JiakClientException if proxy URI is not string.
    def proxy=(uri)
      unless(uri.nil?)
        unless uri.is_a?(String)
          raise JiakClientException, "Proxy URI should be a string."
        end
        RestClient.proxy = uri
      end
      @proxy = uri
    end

    # :call-seq:
    #   set_params(req_params={})  ->  hash
    #
    # Set specified request parameters without changing unspecified ones. This
    # method merges the passed parameters with the current settings.
    def set_params(req_params={})
      check_opts(req_params,VALID_PARAMS,JiakClientException)
      @params.merge!(req_params)
    end

    # :call-seq:
    #   params = req_params
    #
    # Set default params for Jiak client requests.
    #
    def params=(req_params)
      check_opts(req_params,VALID_PARAMS,JiakClientException)
      @params = req_params
    end

    # :call-seq:
    #   params  ->  hash
    #
    # Copy of the current parameters hash.
    def params
      @params.dup
    end

    # :call-seq:
    #   set_schema(bucket)  -> nil
    #
    # Set the Jiak server schema for a bucket. The schema is determined by the
    # JiakData associated with the JiakBucket.
    #
    # Raise JiakClientException if the bucket is not a JiakBucket.
    #
    def set_schema(bucket)
      unless bucket.is_a?(JiakBucket)
        raise JiakClientException, "Bucket must be a JiakBucket."
      end
      resp = RestClient.put(jiak_uri(bucket),
                            bucket.schema.to_jiak.to_json,
                            :content_type => APP_JSON,
                            :accept => APP_JSON)
    end

    # :call-seq:
    #   schema(bucket)  -> JiakSchema
    #
    # Get the data schema for a bucket on a Jiak server. This involves a call
    # to the Jiak server. See JiakBucket#schema for a way to get this
    # information without server access.
    def schema(bucket)
      JiakSchema.from_jiak(bucket_info(bucket,SCHEMA))
    end

    # :call-seq:
    #   client.keys(bucket)  -> array
    #
    # Get an Array of all known keys for the specified bucket. Since key lists
    # are updated asynchronously the returned array can be out of date
    # immediately after a put or delete.
    def keys(bucket)
      bucket_info(bucket,KEYS)
    end

    # :call-seq:
    #   store(object,opts={})  -> JiakObject or key
    #
    # Stores user-defined data (wrapped as a JiakObject) in Riak.
    # Successful server writes return either the storage key or the
    # stored JiakObject depending on the option <code>key</code>. The object
    # for storage must be JiakObject.
    #
    # =====Valid options
    # <code>:return</code> -- If <code>:key</code>, return the key under which
    # the data was stored. If <code>:object</code> return the stored JiakObject
    # (which includes Riak context). Defaults to <code>:key</code>.<br/>
    # <code>:writes</code><br/>
    # <code>:durable_writes</code><br/>
    # <code>:reads</code><br/>
    #
    # Raise JiakClientException if object not a JiakObject or illegal options
    # are passed.<br/>
    # Raise JiakResourceException on RESTful HTTP errors.
    #
    def store(jobj,opts={})
      check_opts(opts,[:return,:reads,:writes,:durable_writes],
                 JiakClientException)
      req_params = {
        WRITES => opts[:writes] || @params[:writes], 
        DURABLE_WRITES => opts[:durable_writes] || @params[:durable_writes],
        READS => opts[:reads] || @params[:reads]
      }
      req_params[RETURN_BODY] = (opts[:return] == :object)

      begin
        uri = jiak_uri(jobj.bucket,jobj.key,req_params)
        payload = jobj.to_jiak.to_json
        headers = { 
          :content_type => APP_JSON,
          :accept => APP_JSON }
        # Decision tree:
        #   If key empty POST
        #   Else PUT
        #   If object true, return JiakObject
        #   Else
        #    POST - parse key from location header
        #    PUT - return the given key
        key_empty = jobj.key.empty?
        if(key_empty)
          resp = RestClient.post(uri,payload,headers)
        else
          resp = RestClient.put(uri,payload,headers)
        end
        
        if(req_params[RETURN_BODY])
          JiakObject.from_jiak(JSON.parse(resp),jobj.bucket.data_class)
        elsif(key_empty)
          resp.headers[:location].split('/').last
        else
          jobj.key
        end
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("put", err)
      rescue RestClient::Exception => err
        fail_with_message("put", err)
      end
    end
    
    # :call-seq:
    #   get(bucket,key,opts={})  -> JiakObject
    #
    # Get data stored on a Jiak server at a bucket/key. The user-defined data
    # stored on the Jiak server is inflated inside a JiakObject that also
    # includes Riak storage information. Data inflation is controlled by the
    # data class associated with the bucket of this call.
    #
    # Since the data schema validation that occurs on the Jiak server validates
    # to the last schema set for that Jiak server bucket, it is imperative that
    # schema be the same (or at least consistent) with the schema associated
    # with this bucket at retrieval time. If you only store homogeneous objects
    # in a bucket this will not be an issue.
    #
    # The bucket must be a JiakBucket and the key must be a non-empty
    # String.
    #
    # =====Valid options
    # <code>:reads</code>
    #
    # Raise JiakClientException if bucket not a JiakBucket.<br/>
    # Raise JiakResourceNotFound if resource not found on Jiak server.<br/>
    # Raise JiakResourceException on other HTTP RESTful errors.
    #
    def get(bucket,key,opts={})
      unless bucket.is_a?(JiakBucket)
        raise JiakClientException, "Bucket must be a JiakBucket."
      end
      check_opts(opts,[:reads],JiakClientException)
      req_params = {READS => opts[:reads] || @params[:reads]}

      begin
        uri = jiak_uri(bucket,key,req_params)
        resp = RestClient.get(uri, :accept => APP_JSON)
        JiakObject.from_jiak(JSON.parse(resp),bucket.data_class)
      rescue RestClient::ResourceNotFound => err
        raise JiakResourceNotFound, "failed get: #{err.message}"
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("get", err)
      rescue RestClient::Exception => err
        fail_with_message("get",err)
      end
    end

    # :call-seq:
    #   delete(bucket,key,opts={})  -> true or false
    #
    # Delete the JiakObject stored at the bucket/key.
    #
    # =====Valid options
    # <code>:waits</code>
    #
    # Raise JiakResourceException on RESTful HTTP errors.
    #
    def delete(bucket,key,opts={})
      check_opts(opts,[:waits],JiakClientException)
      begin
        req_params = {RESPONSE_WAITS => opts[:waits] || @params[:waits]}
        uri = jiak_uri(bucket,key,req_params)
        RestClient.delete(uri, :accept => APP_JSON)
        true
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("delete", err)
      rescue RestClient::Exception => err
        fail_with_message("delete", err)
      end
    end

    # :call-seq:
    #   walk(bucket,key,query,data_class)  -> array
    #
    # Return an array of JiakObjects retrieved by walking a query links
    # array starting with the links for the object at bucket/key. The
    # data_class is used to inflate the data objects returned in the
    # JiakObject array.
    #
    # See QueryLink for a description of the <code>query</code> structure.
    def walk(bucket,key,query,data_class)
      begin
        start = jiak_uri(bucket,key)
        case query
        when QueryLink
          uri = start+'/'+query.for_uri
        when Array
          uri = query.inject(start) {|build,link| build+'/'+link.for_uri}
        else
          raise QueryLinkException, 'failed: query must be '+
            'a QueryLink or an Array of QueryLink objects'
        end
        resp = RestClient.get(uri, :accept => APP_JSON)
        # JSON.parse(resp)['results'][0]
        JSON.parse(resp)['results'][0].map do |jiak|
          JiakObject.from_jiak(jiak,data_class)
        end
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("put", err)
      rescue RestClient::Exception => err
        fail_with_message("put", err)
      end
    end

    # :call-seq:
    #    client == other -> true or false
    #
    # Equality -- JiakClients are equal if they have the same URI
    def ==(other)
      (@server == other.server) rescue false
    end
    
    # :call-seq:
    #    eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a JiakClint with the
    # same URI.
    def eql?(other)
      other.is_a?(JiakClient) &&
        @server.eql?(other.server)
    end

    def hash    # :nodoc:
      @server.hash
    end

    # Build the URI for accessing the Jiak server.
    def jiak_uri(bucket,key="",params={})
      uri = "#{@server}#{URI.encode(bucket.name)}"
      uri += "/#{URI.encode(key)}" unless key.empty?
      qstring = params.reject {|k,v| v.nil?}.map{|k,v| "#{k}=#{v}"}.join('&')
      uri += "?#{URI.encode(qstring)}"  unless qstring.empty?
      uri
    end
    private :jiak_uri
    
    # Get either the schema or keys for the bucket.
    def bucket_info(bucket,info)
      ignore = (info == SCHEMA) ? KEYS : SCHEMA
      begin
        uri = jiak_uri(bucket,"",{ignore => false})
        JSON.parse(RestClient.get(uri, :accept => APP_JSON))[info]
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("get", err)
      rescue RestClient::Exception => err
        fail_with_message("get", err)
      end
    end
    private :bucket_info

    def fail_with_response(action,err)
      raise( JiakResourceException,
             "failed #{action}: HTTP code #{err.http_code}: #{err.http_body}")
    end
    private :fail_with_response

    def fail_with_message(action,err)
      raise JiakResourceException, "failed #{action}: #{err.message}"
    end
    private :fail_with_message

  end

end
