module RiakRest

  # Represents a Jiak link.
  #--
  # CxTBD Further description
  #++
  # ===Usage
  # <code>
  #   link = JiakLink.create(:bucket => 'person', :key => 'remy', :tag => 'child')
  #   link = JiakLink.create(['person','remy','child']
  #   link = JiakLink.create(['person',JiakLink::ANY,'child']
  # </code>
  class JiakLink

    private_class_method :new

    attr_reader :bucket, :key, :tag

    # Jiak (erlang) wildcard character (atom)
    ANY = '_'

    # opts hash keys can be either strings or symbols. Any missing or empty
    # keys are set to ANY.
    def initialize(opts)  # nodoc:
      [:bucket,:key,:tag].each do |key|
        opts[key] = opts[key] || opts[key.to_s] || ANY
        opts[key].strip!
        opts[key] = ANY if opts[key].empty?
      end
      @bucket = opts[:bucket]
      @key = opts[:key]
      @tag = opts[:tag]
    end

    # call-seq:
    #    JiakLink.create(opts)  -> JiakLink
    #
    # Create a link from either a Hash or a three-element Array.
    # 
    # ====Hash
    # <code>:bucket</code> :: Bucket or bucket name
    # <code>:key</code> :: Key
    # <code>:tag</code> :: Tag
    #
    # Notes
    # * Keys can either be strings or symbols.
    # * Values must be strings.
    # * All keys are optional. Missing keys or nil values are set to
    #   JiakLink::ANY.
    #
    # ====Array
    # <code>['b','k','t']</code> --- Three-element array of strings
    def self.create(opts={})
      case opts
      when Hash
        new(transform_opts(opts))
      when Array
        new(transform_arr(opts))
      else
        raise JiakLinkException, "Can only create JiakLink from hash or array"
      end
    end

    # call-seq:
    #    link.for_jiak  -> JSON
    #
    # JSON representation of this JiakLink.
    def for_jiak
      [@bucket, @key, @tag]
    end

    # call-seq:
    #    link.for_uri  -> URI encoded string
    #
    # URI represent this JiakLink, i.e, a string suitable for inclusion in an
    # URI.
    def for_uri
      URI.encode(for_jiak.join(','))
    end

    # call-seq:
    #    link.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <i>link</i> and <i>other</i> contain the
    # same attribute values.
    def eql?(other)
      other.is_a?(JiakLink) &&
        @bucket.eql?(other.bucket) &&
        @key.eql?(other.key) &&
        @tag.eql?(other.tag)
    end

    # call-seq:
    #    link == other -> true or false
    #
    # Equality -- JiakLinks are equal if they contain the same attribute values
    def ==(other)
      (@bucket == other.bucket &&
       @key    == other.key    &&
       @tag    == other.tag) rescue false
    end

    # String representation of this JiakLink.
    def to_s
      '["'+@bucket+'","'+@key+'","'+@tag+'"]'
    end

    private
    def self.transform_opts(opts)
      opts[:bucket] = bucket_to_name(opts[:bucket])
      [:bucket,:key,:tag].each do |opt|
        opts[opt] = opts[opt] || opts[opt.to_s] || ANY
        unless opts[opt].is_a?(String)
          raise JiakLinkException, "Link elements must be Strings."
        end
        opts[opt].strip!
        opts[opt] = ANY if opts[opt].empty?
      end
      opts
    end

    def self.transform_arr(arr)
      unless arr.size == 3
        raise JiakLinkException, "Link array must have 3 elements"
      end
      arr[0] = bucket_to_name(arr[0])
      transform_opts({:bucket => arr[0], :key => arr[1], :tag => arr[2]})
    end

    def self.bucket_to_name(arg)
      arg.is_a?(JiakBucket) ? arg.name : arg
    end

  end
end
