module RiakRest

  # Restful client interaction with a Riak document store via a JSON
  # interface. The Riak RESTful server is called Jiak.
  class JiakClient

    # :stopdoc:
    APP_JSON = 'application/json'
    JSON_DATA = 'json'

    RETURN_BODY = 'returnbody'
    READS = 'r'
    WRITES = 'w'
    DURABLE_WRITES = 'dw'
    RESPONSE_WAITS = 'rw'

    KEYS='keys'
    SCHEMA='schema'
    # :startdoc:

    # :call-seq:
    #   JiakClient.new(server_uri)  -> uri
    #
    # Create a new client for Riak RESTful (Jiak) interaction with the server at
    # the specified URI.
    #
    # Raise JiakClientException if the server URI is not a string.
    #
    def initialize(server_uri='http://127.0.0.1:8002/jiak/')
      unless server_uri.is_a?(String)
        raise JiakClientException, "Jiak server URI shoud be a String."
      end
      @server_uri = server_uri
      @server_uri += '/' unless @server_uri.end_with?('/')
      @server_uri
    end

    # :call-seq:
    #   JiakClient.create(server_uri)  -> uri
    #
    # Create a new client for Riak RESTful (Jiak) interaction with the server at
    # the specified URI.
    #
    # Raise JiakClientException if the server URI is not a string.
    #
    def self.create(server_uri)
      new(server_uri)
    end

    # :call-seq:
    #   client.set_schema(bucket)  -> nil
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
      resp = RestClient.put(jiak_uri(bucket.name),
                            bucket.schema.to_jiak,
                            :content_type => APP_JSON,
                            :data_type => JSON_DATA,
                            :accept => APP_JSON)
    end

    # :call-seq:
    #   client.schema(bucket)  -> JiakSchema
    #
    # Get the data schema for a bucket on a Jiak server. This involves a call
    # to the Jiak server. See JiakBucket#schema for a way to get this
    # information without server access.
    def schema(bucket)
      JiakSchema.create(bucket_info(bucket,SCHEMA))
    end

    # :call-seq:
    #   client.keys(bucket)  -> []
    #
    # Get an Array of all known keys for the specified bucket. Since key lists
    # are updated asynchronously the returned array can be out of date
    # immediately after a put or delete.
    def keys(bucket)
      bucket_info(bucket,KEYS)
    end

    # :call-seq:
    #   client.store(object,opts={})  -> JiakObject or key
    #
    # Stores user-defined data (wrapped in a JiakObject) on the Jiak server. To
    # prepare the user-defined data for JSON transport JiakData#to_jiak is
    # called on the user-defined data. That call is expected to return a Ruby
    # hash representation of the writable JiakData fields that can then be
    # JSONized for HTTP transport. Successful server writes return either the
    # storage key or the stored JiakObject. The object for storage must be
    # JiakObject. Valid options are:
    #
    # <code>key</code>:: If <code>true</code>, on success return the Riak key used to store the JiakObject; otherwise return the stored JiakObject. Defaults to <code>true</code>.
    # <code>writes</code>:: The number of Riak nodes that must successfully store the data value. Defaults to the value set on the Riak cluster. In general you do not need to provide this value on the Jiak interface.
    # <code>durable_writes</code>:: The number of Riak nodes (<code>< writes</code>) that must successfully store the data value in a durable manner.  Defaults to the value set on the Riak cluster. In general you do not need to provide this value on the Jiak interface.
    #
    # Raise JiakClientException on RESTful HTTP errors.
    #
    def store(jobj,opts={})
      uri_opts = {WRITES => opts[:writes], DURABLE_WRITES => opts[:durable_writes]}
      uri_opts[RETURN_BODY] = opts[:key] || true

      begin
        uri = jiak_uri(jobj.bucket,jobj.key,uri_opts)
        payload = jobj.to_jiak
        req_opts = { 
          :content_type => APP_JSON,
          :data_type => JSON_DATA, 
          :accept => APP_JSON }

        # resp = jobj.key.empty? ? RestClient.post(uri,payload,req_opts) :
        #   RestClient.put(uri,payload,req_opts)
        # opts[RETURN_BODY] ? JiakObject.from_jiak(resp,jobj.bucket.data_class) : resp

        # CxHack --Begin--
        # As of Riak 0.6 put/post with returnbody=false returns nil rather than
        # the key. The comment lines above should work in the future. (They
        # worked until Riak 0.5). The lines below are a current hack which
        # always sets returnbody=true then returns just the key if the returned
        # object wasn't requested.
        return_body = opts[RETURN_BODY]
        opts[RETURN_BODY] = true
        uri = jiak_uri(jobj.bucket,jobj.key,opts)
        resp = jobj.key.empty? ? RestClient.post(uri,payload,req_opts) :
          RestClient.put(uri,payload,req_opts)
        resp_object = JiakObject.from_jiak(resp,jobj.bucket.data_class)
        return_body ? resp_object : resp_object.key
        # CxHack --End--
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("put", err)
      rescue RestClient::Exception => err
        fail_with_message("put", err)
      end
    end
    
    # :call-seq:
    #   client.get(bucket,key,opts={})  -> JiakObject
    #
    # Get data stored on a Jiak server at a bucket/key. The user-defined data
    # stored on the Jiak server is inflated inside a JiakObject that also
    # includes Riak storage information. Data inflation is controlled by the
    # data class associated with the bucket of this call. Since the data schema
    # validation that occurs on the Jiak server validates to the last schema
    # set for that Jiak server bucket, it is imperative that schema be the same
    # (or at least consistent) with the schema associated with this bucket at
    # retrieval time.
    #
    # The bucket must be a JiakBucket and the key must be a non-empty
    # String. Valid options are:
    #
    # <code>:reads</code> --- The number of Riak nodes that must successfully
    # reply with the data value. Defaults to the value set on the Riak
    # cluster. In general you do not need to provide this value on the Jiak
    # interface.
    #
    # Raise JiakClientException if the bucket is not a JiakBucket or on RESTful HTTP errors.
    # Raise JiakResourceNotFound if the resource not found on the Jiak server.
    # Raise JiakClientException on other HTTP RESTful errors.
    #
    def get(bucket,key,opts={})
      unless bucket.is_a?(JiakBucket)
        raise JiakClientException, "Bucket must be a JiakBucket."
      end
      uri_opts = {READS => opts[:reads]}

      begin
        uri = jiak_uri(bucket.name,key,uri_opts)
        resp = RestClient.get(uri, :accept => APP_JSON)
        JiakObject.from_jiak(resp,bucket.data_class)
      rescue RestClient::ResourceNotFound => err
        raise JiakResourceNotFound, "failed get: #{err.message}"
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("get", err)
      rescue RestClient::Exception => err
        fail_with_message("get",err)
      end
    end

    # :call-seq:
    #   client.delete(bucket,key,opts={})  -> <code>true</code> on success.
    #
    # Delete the JiakObject stored at the bucket/key. Valid options are:
    #
    # <code>:waits</code> --- The number of Riak nodes that must reply the
    # delete has occurred before success. Defaults to the value set on the Riak
    # cluster. In general you do not need to provide this value on the Jiak
    # interface.
    #
    # Raise JiakClientException on RESTful HTTP errors.
    #
    def delete(bucket,key,opts={})
      begin
        uri_opts = {RESPONSE_WAITS => opts[:waits]}
        uri = jiak_uri(bucket,key,uri_opts)
        RestClient.delete(uri, :accept => APP_JSON)
        true
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("delete", err)
      rescue RestClient::Exception => err
        fail_with_message("delete", err)
      end
    end

    # CxTDB description
    def walk(bucket,key,walker)
      begin
        start = jiak_uri(bucket,key)
        case walker
        when JiakLink
          uri = start+'/'+walker.for_uri
        when Array
          uri = walker.inject(start) {|build,link| build+'/'+link.for_uri}
        else
          raise JiakLinkException, 'failed: walker must be '+
            'a JiakList or an Array of JiakList objects'
        end
        resp = RestClient.get(uri, :accept => APP_JSON)
        results = JSON.parse(resp)['results'][0]
      rescue RestClient::ExceptionWithResponse => err
        fail_with_response("put", err)
      rescue RestClient::Exception => err
        fail_with_message("put", err)
      end
    end

    # :call-seq:
    #   client.server_uri  -> string
    #
    # String representation of the base URI of the Jiak server.
    def server_uri
      @server_uri
    end

    private
    # Build the URI for accessing the Jiak server.
    def jiak_uri(bucket,key="",opts={})
      bucket_name = bucket.is_a?(JiakBucket) ? bucket.name : bucket

      uri = @server_uri + URI.encode(bucket_name)
      uri += '/'+URI.encode(key) unless key.empty?
      uri += query_string(opts) unless opts.empty?
      uri
    end
    
    # Build the query string portion of the URI based on passed options.
    def query_string(opts={})
      result = ""
      pre = '?'
      opts.reject {|field,value| value.nil?} .each do |field,value|
        result += "#{pre}#{field}=#{value}"
        pre = '&'
      end
      result
    end

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

    def fail_with_response(action,err)
      raise( JiakClientException,
             "failed #{action}: HTTP code #{err.http_code}: #{err.http_body}")
    end

    def fail_with_message(action,err)
      raise JiakClientException, "failed #{action}: #{err.message}"
    end

  end

end
