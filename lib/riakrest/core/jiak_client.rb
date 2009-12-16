module RiakRest

  # Client for restful interaction with a Riak document store via the Jiak
  # HTTP/JSON interface. RiakRest Core Client classes expose Jiak server
  # constructs and concepts. JiakResource wraps Jiak interaction at a higher
  # level of abstraction and takes care of much of the Core Client bookkeeping
  # tasks. See JiakResource.
  #
  # ===Example
  #  require 'riakrest'
  #  include RiakRest
  #
  #  class PeopleData
  #    include JiakData
  #    attr_accessor :name, :age
  #  end
  #
  #  client = JiakClient.new("http://localhost:8002/jiak")
  #  bucket = JiakBucket.new('people',PeopleData)
  #  client.set_schema(bucket)
  #
  #  remy = client.store(JiakObject.new(:bucket => bucket,
  #                                     :data => PeopleData.new(:name => "remy",
  #                                                             :age => 10)),
  #                      :return => :object)
  #  callie = client.store(JiakObject.new(:bucket => bucket,
  #                                       :data => PeopleData.new(:name => "Callie",
  #                                                               :age => 12)),
  #                        :return => :object)
  #
  #  remy.data.name = "Remy"
  #  remy << JiakLink.new(bucket,callie.key,'sister')
  #  client.store(remy)
  #
  #  sisters = client.walk(bucket,remy.key,
  #                        QueryLink.new(bucket,'sister'),PeopleData)
  #  sisters[0].eql?(callie)                                       #  => true
  #
  #  client.delete(bucket,remy.key)
  #  client.delete(bucket,callie.key)
  #
  # See JiakResource for the same example using the RiakRest Resource layer.
  class JiakClient

    attr_accessor :server, :proxy, :params

    # :stopdoc:
    APP_JSON               = 'application/json'
    APP_JSON.freeze

    KEYS                   = 'keys'
    SCHEMA                 = 'schema'
    KEYS.freeze
    SCHEMA.freeze

    RETURN_BODY            = 'returnbody'
    READS                  = 'r'
    WRITES                 = 'w'
    DURABLE_WRITES         = 'dw'
    DELETES                = 'rw'
    COPY                   = 'copy'
    READ                   = 'read'

    RETURN_BODY.freeze
    READS.freeze
    WRITES.freeze
    DURABLE_WRITES.freeze
    DELETES.freeze
    COPY.freeze
    READ.freeze

    CLIENT_PARAMS = [:reads,:writes,:durable_writes,:deletes,:proxy]
    STORE_PARAMS  = [:writes,:durable_writes,:return,:reads,:copy,:read]
    GET_PARAMS    = [:reads,:read]
    DELETE_PARAMS = [:delete]
    WALK_PARAMS   = [:read]

    CLIENT_PARAMS.freeze
    STORE_PARAMS.freeze
    GET_PARAMS.freeze
    DELETE_PARAMS.freeze
    WALK_PARAMS.freeze
    # :startdoc:

    # :call-seq:
    #   JiakClient.new(uri,opts={})  -> uri
    #
    # Create a new client for Riak RESTful (Jiak) interaction with the server at
    # the specified URI. Go through a proxy if proxy option specified.
    #
    # =====Valid options
    # <code>:reads</code>:: Minimum number of responding nodes for successful reads.
    # <code>:writes</code>:: Minimum number of responding nodes for successful writes. Writes can be buffered on the server nodes for performance.
    # <code>:durable_writes</code>:: Minimum number of responding nodes that must perform a durable write to a persistence layer.
    # <code>:deletes</code>:: Minimum number of responding nodes for successful delete.
    # <code>:proxy</code>:: Proxy server URI
    #
    # The configuration of a Riak cluster includes server setting for the
    # <code>writes, durable_writes, reads,</code> and <code>deletes</code>
    # parameters. None of these request parameter are required by RiakRest, and
    # their use within RiakRest is to override the Riak cluster settings,
    # either at the JiakClient level or the individual request level.
    #
    # Settings passed to individual <code>get, store,</code> and
    # <code>delete</code> requests take precendence over the setting maintained
    # by a JiakClient. Any request parameter not set in JiakClient or on an
    # individual request will default to the values set in the Riak cluster.
    # 
    def initialize(uri, opts={})
      check_opts(opts,CLIENT_PARAMS,JiakClientException)
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
    # Set specified client request parameters without changing unspecified
    # ones. This method merges the passed parameters with the current settings.
    def set_params(req_params={})
      check_opts(req_params,CLIENT_PARAMS,JiakClientException)
      @params.merge!(req_params)
    end

    # :call-seq:
    #   params = req_params
    #
    # Set default params for Jiak client requests.
    #
    def params=(req_params)
      check_opts(req_params,CLIENT_PARAMS,JiakClientException)
      @params = req_params
    end

    # :call-seq:
    #   params  ->  hash
    #
    # Copy of the current request parameters hash.
    def params
      @params.dup
    end

    # :call-seq:
    #   set_schema(bucket,schema=nil)  -> nil
    #
    # Set the Jiak server schema for a bucket. If a JaikSchema is given, bucket
    # must be a string; otherwise, if the schema is not given bucket must be a
    # JiakBucket and the associated JiakData schema is used.
    #
    # Raise JiakClientException if the bucket is not a JiakBucket.
    # Raise JiakClientException if the schema is not a JiakSchema.
    def set_schema(bucket,schema=nil)
      if(schema.nil?)
        unless bucket.is_a?(JiakBucket)
          raise JiakClientException, "Bucket must be a JiakBucket."
        end
        bucket_name = bucket.name
        schema = bucket.schema
      else
        unless(bucket.is_a?(String))
          raise JiakClientException, "Bucket must be a string name."
        end
        unless(schema.is_a?(JiakSchema))
          raise JiakClientException, "Schema must be a JiakSchema."
        end
        bucket_name = bucket
      end
      resp = RestClient.put(jiak_uri(bucket_name),
                            schema.to_jiak.to_json,
                            :content_type => APP_JSON,
                            :accept => APP_JSON)
    end

    # :call-seq:
    #   schema(bucket)  -> JiakSchema
    #
    # Get the data schema for a bucket on a Jiak server.
    def schema(bucket)
      JiakSchema.jiak_create(bucket_info(bucket,SCHEMA))
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
    # <code>:return</code> -- <code>:key</code> (default), returns the key
    # use to store the data, or <code>:object</code> returns the stored
    # JiakObject with included Riak context.<br/>
    # <code>:writes</code><br/>
    # <code>:durable_writes</code><br/>
    # <code>:reads</code><br/>
    # <code>:copy</code> -- <code>true</code> to indicate the any data
    # fields already stored on the server and not explicitly altered by this
    # write should be copied and left unchanged. Default is
    # <code>false</code><br/>.
    # <code>:read</code> -- Comma separated list of fields to be returned on
    # read.
    #
    # See JiakClient#new for description of <code>writes,
    # durable_writes,</code> and <code>reads</code> parameters. The
    # <code>reads</code> and <code>read</code> parameter only takes effect if
    # the JiakObject is being returned (which involves reading the writes).
    #
    # Raise JiakClientException if object not a JiakObject or illegal options
    # are passed.<br/>
    # Raise JiakResourceException on RESTful HTTP errors.
    #
    def store(jobj,opts={})
      check_opts(opts,STORE_PARAMS,JiakClientException)
      req_params = {
        WRITES => opts[:writes] || @params[:writes], 
        DURABLE_WRITES => opts[:durable_writes] || @params[:durable_writes],
        COPY => opts[:copy]
      }
      if(opts[:return] == :object)
        req_params[RETURN_BODY] = true
        req_params[READS] = opts[:reads] || @params[:reads]
        req_params[READ] = opts[:read]
      end

      begin
        uri = jiak_uri(jobj.bucket,jobj.key) << jiak_qstring(req_params)
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
          JiakObject.jiak_create(JSON.parse(resp),jobj.bucket.data_class)
        elsif(key_empty)
          resp.headers[:location].split('/').last
        else
          jobj.key
        end
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("store", err)
      rescue RestClient::Exception => err
        fail_with_message("store", err)
      rescue Errno::ECONNREFUSED => err
        fail_connection("store", err)
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
    # <code>:reads</code> --- See JiakClient#new
    #
    # Raise JiakClientException if bucket not a JiakBucket.<br/>
    # Raise JiakResourceNotFound if resource not found on Jiak server.<br/>
    # Raise JiakResourceException on other HTTP RESTful errors.
    #
    def get(bucket,key,opts={})
      unless bucket.is_a?(JiakBucket)
        raise JiakClientException, "Bucket must be a JiakBucket."
      end
      check_opts(opts,GET_PARAMS,JiakClientException)
      req_params = {
        READS => opts[:reads] || @params[:reads],
        READ  => opts[:read]
      }

      begin
        uri = jiak_uri(bucket,key) << jiak_qstring(req_params)
        resp = RestClient.get(uri, :accept => APP_JSON)
        JiakObject.jiak_create(JSON.parse(resp),bucket.data_class)
      rescue RestClient::ResourceNotFound => err
        raise JiakResourceNotFound, "failed get: #{err.message}"
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("get", err)
      rescue RestClient::Exception => err
        fail_with_message("get",err)
      rescue Errno::ECONNREFUSED => err
        fail_connection("get", err)
      end
    end

    # :call-seq:
    #   delete(bucket,key,opts={})  -> true or false
    #
    # Delete the JiakObject stored at the bucket/key.
    #
    # =====Valid options
    # <code>:deletes</code> --- See JiakClient#new
    #
    # Raise JiakResourceException on RESTful HTTP errors.
    #
    def delete(bucket,key,opts={})
      check_opts(opts,DELETE_PARAMS,JiakClientException)
      begin
        req_params = {DELETES => opts[:deletes] || @params[:deletes]}
        uri = jiak_uri(bucket,key) << jiak_qstring(req_params)
        RestClient.delete(uri,:accept => APP_JSON)
        true
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("delete", err)
      rescue RestClient::Exception => err
        fail_with_message("delete", err)
      rescue Errno::ECONNREFUSED => err
        fail_connection("delete", err)
      end
    end

    # :call-seq:
    #   exist?(bucket,key)  -> true or false
    #
    # Return true if a resource exists at bucket/key
    def exist?(bucket,key)
      begin
        uri = jiak_uri(bucket,key)
        RestClient.head(uri,:accept => APP_JSON)
        true
      rescue RestClient::ResourceNotFound
        false
      rescue Errno::ECONNREFUSED => err
        fail_connection("exist?", err)
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
    def walk(bucket,key,query,data_class,opts={})
      check_opts(opts,WALK_PARAMS,JiakClientException)
      req_params = {
        READ => opts[:read]
      }
      begin
        start = jiak_uri(bucket,key)
        case query
        when QueryLink
          uri = "#{start}/#{query.for_uri}"
        when Array
          uri = query.inject(start) {|build,link| build+'/'+link.for_uri}
        else
          raise QueryLinkException, 'failed: query must be '+
            'a QueryLink or an Array of QueryLink objects'
        end
        uri << jiak_qstring(req_params)
        resp = RestClient.get(uri, :accept => APP_JSON)
        JSON.parse(resp)['results'][0].map do |jiak|
          JiakObject.jiak_create(jiak,data_class)
        end
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("walk", err)
      rescue RestClient::Exception => err
        fail_with_message("walk", err)
      rescue Errno::ECONNREFUSED => err
        fail_connection("walk", err)
      end
    end

    # :call-seq:
    #    client == other -> true or false
    #
    # Equality --- JiakClients are equal if they have the same URI
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
    def jiak_uri(bucket,key="")
      bucket_name = bucket.is_a?(JiakBucket) ? bucket.name : bucket
      uri = "#{@server}#{URI.encode(bucket_name)}"
      uri << "/#{URI.encode(key)}" unless key.empty?
      uri
    end
    private :jiak_uri

    # Build query string. Strip keys with nil values.
    def jiak_qstring(params={})
      qstring = ""
      params.delete_if {|k,v| v.nil?}
      unless(params.empty?)
        qstring << "?" << params.map{|k,v| "#{k}=#{v}"}.join('&')
      end
      qstring
    end
    private :jiak_qstring
    
    # Get either the schema or keys for the bucket.
    def bucket_info(bucket,info)
      ignore = (info == SCHEMA) ? KEYS : SCHEMA
      begin
        uri = jiak_uri(bucket,"") << jiak_qstring({ignore => false})
        JSON.parse(RestClient.get(uri, :accept => APP_JSON))[info]
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("info", err)
      rescue RestClient::Exception => err
        fail_with_message("info", err)
      rescue Errno::ECONNREFUSED => err
        fail_connection("info", err)
      end
    end
    private :bucket_info

    def fail_with_response(action,err)
      raise(JiakResourceException,
            "failed #{action}: HTTP code #{err.http_code}: #{err.http_body}")
    end
    private :fail_with_response

    def fail_with_message(action,err)
      raise JiakResourceException, "failed #{action}: #{err.message}"
    end
    private :fail_with_message

    def fail_connection(action,err)
      raise(JiakClientException,
            "failed #{action}: Connection refused for server #{@server}")
    end
    private :fail_connection

  end

end
