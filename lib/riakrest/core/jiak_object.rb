module RiakRest

  # Wrapper for JiakData.
  class JiakObject

    attr_accessor :bucket, :key, :data, :links
    attr_reader :riak

    private_class_method :new
    
    def initialize(bucket,key,data,links,vclock,vtag,lastmod) # nodoc:
      @bucket = bucket
      @key = key
      @data = data
      @links = links

      @riak = {:vclock => vclock, :vtag => vtag, :lastmod => lastmod} if(vclock)
    end

    # call-seq:
    #   JiakObject.create(opts)  -> JiakObject
    #
    # CxINC
    # Create a Jiak object to be stored in a bucket.
    def self.create(opts={})
      opts = { 
        :links   => [],
        :vclock  => nil,
        :vtag    => nil,
        :lastmod => nil}.merge(opts)

      bucket = check_bucket(opts[:bucket])
      data = check_data(opts[:data])
      key = transform_key(opts[:key] || data.keygen)
      links = check_links(opts[:links])

      new(bucket,key,data,links,
          opts[:vclock],opts[:vtag],opts[:lastmod])
    end

    # call-seq:
    #    JiakObject.from_jiak(jiak_json)  -> JiakObject
    #
    # Create a JiakObject from JSON returned by the Jiak server.
    def self.from_jiak(jiak_json,klass)
      jiak = JSON.parse(jiak_json)

      jiak[:bucket] = JiakBucket.create(jiak.delete('bucket'),klass)
      jiak[:data] = klass.jiak_create(jiak.delete('object'))
      jiak[:links] = jiak.delete('links').map {|link| JiakLink.create(link)}

      create(jiak.inject({}) do |build, (key, value)|
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
      @bucket = JiakObject.check_bucket(bucket)
    end

    # call-seq:
    #   jiak_object.key = string or nil
    #
    # Sets the key for this JiakObject. Key string is stripped of leading and
    # trailing blanks. A nil key is interpreted as an empty string.
    def key=(key)
      @key = JiakObject.transform_key(key)
    end

    # call-seq:
    #   jiak_object.data = {}
    #
    # Sets the data wrapped by this JiakObject. The data must be a JiakData
    # object.
    def data=(data)
      @data = JiakObject.check_data(data)
    end

    # call-seq:
    #   jiak_object.links = []
    #
    # Sets the links array for this jiak_object. Each array element must be a
    # JiakLink.
    def links=(links)
      @links = JiakObject.check_links(links)
    end

    # call-seq:
    #   jiak_object << JiakLink  -> JiakObject
    #
    # Convenience method for adding a JiakLink to the links for this
    # jiak_object. Duplicate links are ignored. Returns the jiak_object for
    # chaining.
    def <<(link)
      link = JiakObject.check_link(link)
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
    def self.check_bucket(bucket)
      unless bucket.is_a?(JiakBucket)
        raise JiakObjectException, "Data must be a JiakData."
      end
      bucket
    end

    def self.transform_key(key)
      # Change nil key to empty
      key = "" if key.nil?
      unless key.is_a?(String)
        raise JiakObjectException, "Key must be a String" 
      end
      key.strip!
      key
    end

    def self.check_data(data)
      unless data.is_a?(JiakData)
        raise JiakObjectException, "Data must be a JiakData."
      end
      data
    end

    def self.check_links(links)
      unless links.is_a? Array
        raise JiakObjectException, "Links must be an Array"
      end
      links.each do |link|
        check_link(link)
      end
      links
    end

    def self.check_link(link)
      unless link.is_a? JiakLink
        raise JiakObjectException, "Each link must be a JiakLink"
      end
      link
    end

  end

end
