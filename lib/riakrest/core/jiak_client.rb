module RiakRest

  # Restful client interaction with a Riak document store via a JSON
  # interface. See RiakRest for descriptive usage.
  #
  # ====Usage
  # <code>
  #   Person = JiakDataHash.create(:name,:age)
  #   remy = Person.new(:name => "remy", :age => 10)
  #   bucket = JiakBucket.new('person',Person)
  #   client.set_schema(bucket)
  #   jobj = JiakObject.new(:bucket => bucket, :data => remy)
  #   key = client.store(jobj)
  #   remy.name                                # => "remy"
  #   remy.name = "Remy"                       # => "Remy"
  #   remy = client.get(bucket,key)
  #   remy.name                                # => "remy" (overwrote change)
  #   client.delete(bucket,key)
  # </code>
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
    #   JiakClient.new(uri)  -> uri
    #
    # Create a new client for Riak RESTful (Jiak) interaction with the server at
    # the specified URI.
    #
    # Raise JiakClientException if the server URI is not a string.
    #
    def initialize(uri='http://127.0.0.1:8002/jiak/')
      unless uri.is_a?(String)
        raise JiakClientException, "Jiak server URI shoud be a String."
      end
      @uri = uri
      @uri += '/' unless @uri.end_with?('/')
      @uri
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
      resp = RestClient.put(jiak_uri(bucket),
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
      JiakSchema.from_jiak(bucket_info(bucket,SCHEMA))
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
    # Stores user-defined data (wrapped in a JiakObject) on the Jiak
    # server. JiakData#to_jiak is used to prepare user-defined data for JSON
    # transport to Jiak. That call is expected to return a Ruby hash
    # representation of the writable JiakData fields that are JSONized for HTTP
    # transport. Successful server writes return either the storage key or the
    # stored JiakObject depending on the option <code>key</code>. The object
    # for storage must be JiakObject. Valid options are:
    #
    # <code>:object</code> :: If <code>true</code>, on success return the stored JiakObject (which includes Jiak metadata); otherwise return just the key. Default is <code>false</code>
    # <code>:writes</code> :: The number of Riak nodes that must successfully store the data.
    # <code>:durable_writes</code> :: The number of Riak nodes (<code>< writes</code>) that must successfully store the data in a durable manner.
    # <code>:reads</code> :: The number of Riak nodes that must successfully read data if the JiakObject is being returned.
    #
    # If any of the request parameters <code>:writes, :durable_writes,
    # :reads</code> are not set, each first defaults to the value set for the
    # JiakBucket in the JiakObject, then to the value set on the Riak
    # cluster. In general the values set on the Riak cluster should suffice.
    #
    # Raise JiakClientException if object is not a JiakObject or illegal options.
    # Raise JiakResourceException on RESTful HTTP errors.
    #
    def store(jobj,opts={})
      params = jobj.bucket.params
      req_params = {
        WRITES => opts[:writes] || params[:writes], 
        DURABLE_WRITES => opts[:durable_writes] || params[:durable_writes],
        READS => opts[:reads] || params[:reads]
      }
      req_params[RETURN_BODY] = opts[:object]  if opts[:object]

      begin
        uri = jiak_uri(jobj.bucket,jobj.key,req_params)
        payload = jobj.to_jiak
        headers = { 
          :content_type => APP_JSON,
          :data_type => JSON_DATA,
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
    # reply with the data. If not set, defaults first to the value set for the
    # JiakBucket, then to the value set on the Riak cluster. In general the
    # values set on the Riak cluster should suffice.
    #
    # Raise JiakClientException if bucket not a JiakBucket
    # Raise JiakResourceNotFound if the resource not found on the Jiak server.
    # Raise JiakResourceException on other HTTP RESTful errors.
    #
    def get(bucket,key,opts={})
      unless bucket.is_a?(JiakBucket)
        raise JiakClientException, "Bucket must be a JiakBucket."
      end
      req_params = {READS => opts[:reads] || bucket.params[:reads]}

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
    #   client.delete(bucket,key,opts={})  -> <code>true</code> on success.
    #
    # Delete the JiakObject stored at the bucket/key. Valid options are:
    #
    # <code>:waits</code> --- The number of Riak nodes that must reply the
    # delete has occurred before success. If not set, defaults first to the
    # value set for the JiakBucket, then to the value set on the Riak
    # cluster. In general the values set on the Riak cluster should suffice.
    #
    # Raise JiakResourceException on RESTful HTTP errors.
    #
    def delete(bucket,key,opts={})
      begin
        req_params = {RESPONSE_WAITS => opts[:waits] || bucket.params[:waits]}
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
    #   client.walk(bucket,key,walker,data_class)
    #
    # Return an array of JiakObjects by walking links for a bucket and key. The
    # data_class is used to create the data objects wrapped in the returned
    # JiakObjects.
    #
    def walk(bucket,key,walker,data_class)
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
    #   client.uri  -> string
    #
    # String representation of the base URI of the Jiak server.
    def uri
      @uri
    end

    private
    # Build the URI for accessing the Jiak server.
    def jiak_uri(bucket,key="",params={})
      uri = "#{@uri}#{URI.encode(bucket.name)}"
      uri += "/#{URI.encode(key)}" unless key.empty?
      qstring = params.reject {|k,v| v.nil?}.map{|k,v| "#{k}=#{v}"}.join('&')
      uri += "?#{URI.encode(qstring)}"  unless qstring.empty?
      uri
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
      raise( JiakResourceException,
             "failed #{action}: HTTP code #{err.http_code}: #{err.http_body}")
    end

    def fail_with_message(action,err)
      raise JiakResourceException, "failed #{action}: #{err.message}"
    end

  end

end
