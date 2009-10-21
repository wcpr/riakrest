module RiakRest

  # Represents a Jiak link.
  #--
  # CxTBD Further description
  #++
  # ===Usage
  # <code>
  #   link = JiakLink.create(:bucket => 'person', :tag => key, :acc => 'parent')
  #   link = JiakLink.create(['person',key,'parent']
  # </code>
  class JiakLink

    private_class_method :new

    attr_reader :bucket, :tag, :acc

    # Jiak (erlang) wildcard character
    ANY = '_'

    # opts hash keys can be either strings or symbols. Any missing or empty
    # keys are set to ANY.
    def initialize(opts)  # nodoc:
      [:bucket,:tag,:acc].each do |key|
        opts[key] = opts[key] || opts[key.to_s] || ANY
        opts[key].strip!
        opts[key] = ANY if opts[key].empty?
      end
      @bucket = opts[:bucket]
      @tag = opts[:tag]
      @acc = opts[:acc]
    end

    # call-seq:
    #    JiakLink.create(opts)  -> JiakLink
    #
    # Create a link from either a Hash or a three-element Array.
    # 
    # ====Hash
    # <code>bucket</code>:: Bucket name
    # <code>tag</code>:: Tag
    # <code>acc</code>:: Accumulator
    #
    # Notes
    # * Keys can either be strings or symbols.
    # * Values must be strings.
    # * All keys are optional. Missing keys or nil values are set to
    #   JiakLink::ANY.
    #
    # ====Array
    # <code>['b','t','a']</code> --- Three-element array of strings
    def self.create(opts={})
      case opts
      when Hash
        new(transform_opts(opts))
      when Array
        new(transform_arr(opts))
      else
        raise JiakLinkException, "Can only create JiakLink from Hash or Array"
      end
    end

    # call-seq:
    #    link.for_jiak  -> JSON
    #
    # JSON representation of this JiakLink.
    def for_jiak
      [@bucket, @tag, @acc]
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
      (other.bucket.eql?(@bucket) &&
       other.tag.eql?(@tag) &&
       other.acc.eql?(@acc)) rescue false
    end

    # call-seq:
    #    link == other -> true or false
    #
    # Equality -- JiakLinks are equal if they contain the same attribute values.
    def ==(other)
      (other.bucket == @bucket &&
       other.tag == @tag &&
       other.acc == @acc) rescue false
    end

    # String representation of this JiakLink.
    def to_s
      '["'+@bucket+'","'+@tag+'","'+@acc+'"]'
    end

    private
    def self.transform_opts(opts)
      [:bucket,:tag,:acc].each do |opt|
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
      transform_opts({:bucket => arr[0], :tag => arr[1], :acc => arr[2]})
    end

  end
end
