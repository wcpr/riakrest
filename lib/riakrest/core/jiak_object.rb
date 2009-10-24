module RiakRest

  # Wrapper for JiakData.
  class JiakObject

    attr_accessor :bucket, :key, :data, :links
    attr_reader :riak

    # call-seq:
    #   JiakObject.new(opts)  -> JiakObject
    #
    # Create a object for Jiak storage. Valid options:
    # <code>:bucket</code> :: The JiakBucket for storage.
    # <code>:data</code> :: The JiakData to be stored.
    # <code>:key</code> :: The key for the object.
    # <code>:links</code> :: The Jiak links for the object.
    #
    # The bucket and data options are required.
    #
    # The key and links options are optional. If no key is provided, the
    # <code>keygen</code> method of <code>data</code> is used to provide the
    # key. The default implementation of JiakData#keygen is an empty string,
    # which instructs the Jiak server to generate a random key. If no links are
    # provided, the default uses an empty array.
    #
    # There are other options used by the system to maintain the context of the
    # JiakObject on the Riak cluster. These options should not be manually
    # altered and are purposely not described here.
    def initialize(opts)
      opts[:links] ||= []
      check_opts(opts)

      @bucket = check_bucket(opts[:bucket])
      @data = check_data(opts[:data])
      @key = transform_key(opts[:key] || @data.keygen)
      @links = check_links(opts[:links])

      # The Riak context for the object if provided.
      if opts[:vclock]
        @riak = opts.select {|k,v| [:vclock,:vtag,:lastmod].include?(k)}
      end
    end

    # call-seq:
    #    JiakObject.from_jiak(jiak_json)  -> JiakObject
    #
    # Create a JiakObject from JSON returned by the Jiak server.
    def self.from_jiak(jiak_json,klass)
      jiak = JSON.parse(jiak_json)

      jiak[:bucket] = JiakBucket.new(jiak.delete('bucket'),klass)
      jiak[:data] = klass.jiak_create(jiak.delete('object'))
      jiak[:links] = jiak.delete('links').map {|link| JiakLink.new(link)}

      new(jiak.inject({}) do |build, (key, value)|
            build[key.to_sym] = value
            build
          end)
    end

    # call-seq:
    #    jiak_object.to_jiak  -> JSON
    #
    # Create a JSON suitable for sending to a Jiak server.
    def to_jiak
      jiak = {
        :bucket => @bucket.name,
        :key => @key,
        :object => @data.for_jiak,
        :links => @links.map {|link| link.for_jiak}
      }
      if(@riak)
        jiak[:vclock] = @riak[:vclock]
        jiak[:vtag] = @riak[:vtag]
        jiak[:lastmod] = @riak[:lastmod]
      end
      jiak.to_json
    end

    # call-seq:
    #   jiak_object.bucket = bucket
    #
    # Sets the bucket for this JiakObject. Bucket must be a JiakBucket.
    def bucket=(bucket)
      @bucket = check_bucket(bucket)
    end

    # call-seq:
    #   jiak_object.key = string or nil
    #
    # Sets the key for this JiakObject. Key string is stripped of leading and
    # trailing blanks. A nil key is interpreted as an empty string.
    def key=(key)
      @key = transform_key(key)
    end

    # call-seq:
    #   jiak_object.data = {}
    #
    # Sets the data wrapped by this JiakObject. The data must be a JiakData
    # object.
    def data=(data)
      @data = check_data(data)
    end

    # call-seq:
    #   jiak_object.links = []
    #
    # Sets the links array for this jiak_object. Each array element must be a
    # JiakLink.
    def links=(links)
      @links = check_links(links)
    end

    # call-seq:
    #   jiak_object << JiakLink  -> JiakObject
    #
    # Convenience method for adding a JiakLink to the links for this
    # jiak_object. Duplicate links are ignored. Returns the jiak_object for
    # chaining.
    def <<(link)
      link = check_link(link)
      @links << link unless @links.include?(link)
      self
    end

    # call-seq:
    #    jiak_object.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <i>jiak_object</i> and <i>other</i> contain
    # the same attribute values.
    def eql?(other)
      other.is_a?(JiakObject) &&
        @bucket.eql?(other.bucket) &&
        @key.eql?(other.key) &&
        @data.eql?(other.data) &&
        @links.eql?(other.links) &&
        @riak.eql?(other.riak)
    end

    private
    def check_opts(opts)
      valid = [:bucket,:key,:data,:links,:vclock,:vtag,:lastmod]
      err = opts.select {|k,v| !valid.include?(k)}
      unless err.empty?
        raise JiakObjectException, "unrecognized options: #{err.keys}"
      end
      opts
    end

    def check_bucket(bucket)
      unless bucket.is_a?(JiakBucket)
        raise JiakObjectException, "Data must be a JiakData."
      end
      bucket
    end

    def transform_key(key)
      # Change nil key to empty
      key = "" if key.nil?
      unless key.is_a?(String)
        raise JiakObjectException, "Key must be a String" 
      end
      key.strip!
      key
    end

    def check_data(data)
      unless data.is_a?(JiakData)
        raise JiakObjectException, "Data must be a JiakData."
      end
      data
    end

    def check_links(links)
      unless links.is_a? Array
        raise JiakObjectException, "Links must be an Array"
      end
      links.each do |link|
        check_link(link)
      end
      links
    end

    def check_link(link)
      unless link.is_a? JiakLink
        raise JiakObjectException, "Each link must be a JiakLink"
      end
      link
    end

  end

end
