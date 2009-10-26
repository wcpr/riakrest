module RiakRest

  # Represents a Jiak link.
  #--
  # CxTBD Further description
  #++
  # ===Usage
  # <code>
  #   link = JiakLink.new('person','remy','child')
  #   link = JiakLink.new(['person','remy','child'])
  #   link = JiakLink.new('person',JiakLink::ANY,'child')
  # </code>
  class JiakLink

    attr_accessor :bucket, :key, :tag

    # Jiak (erlang) wildcard character (atom)
    ANY = '_'

    # :call-seq:
    #   JiakLink.new(*args)  -> JiakLink
    #
    # Create a link from argument array. Missing, nil, or empty string values
    # are set to JiakLink::ANY.
    #
    # ====Examples
    # The following create JiakLinks with the shown equivalent array structure:
    # <code>
    #   JiakLink.new                       # => ['_','_','_']
    #   JiakLink.new 'b'                   # => ['b','_','_']
    #   JiakLink.new 'b','k'               # => ['b','k','_']
    #   JiakLink.new 'b','k','t'           # => ['b','k','t']
    #
    #   JiakLink.new []                    # => ['_','_','_']
    #   JiakLink.new ['b']                 # => ['b','_','_']
    #   JiakLink.new ['b','k']             # => ['b','k','_']
    #   JiakLink.new ['b','k','t']         # => ['b','k','t']
    #
    #   JikaLink.new ['',nil,' ']          # => ['_','_','_']
    # </code>
    #
    # Passing another JiakLink as an argument makes a copy of that
    # link. Passing a JiakBucket in the first (bucket) position uses the name
    # field of that JiakBucket.
    #
    def initialize(*args)
      case args.size
      when 0
        bucket = key = tag = ANY
      when 1
        if args[0].is_a? String
          bucket = args[0]
          key = tag = ANY
        elsif args[0].is_a? JiakLink
          bucket, key, tag = args[0].bucket, args[0].key, args[0].tag
        elsif args[0].is_a? Array
          bucket, key, tag = args[0][0], args[0][1], args[0][2]
        else
          raise JiakLinkException, "argument error"
        end
      when 2
        bucket, key = args[0], args[1]
        tag = ANY
      when 3
        bucket, key, tag = args[0], args[1], args[2]
      else
        raise JiakLinkException, "too many arguments, (#{args.size} for 3)"
      end
      
      @bucket, @key, @tag  = transform_args(bucket,key,tag)
    end

    # :call-seq
    #   link.bucket = bucket
    #
    # Set the bucket field.
    def bucket=(bucket)
      bucket = bucket.name  if bucket.is_a? JiakBucket
      @bucket = transform_arg(bucket)
    end

    # :call-seq:
    #   link.key = key
    #
    # Set the key field.
    def key=(key)
      @key = transform_arg(key)
    end

    # :call-seq:
    #   link.tag = tag
    #
    # Set the tag field.
    def tag=(tag)
      @tag = transform_arg(tag)
    end

    # :call-seq:
    #   link.for_jiak  -> JSON
    #
    # JSON representation of this JiakLink.
    def for_jiak
      [@bucket, @key, @tag]
    end

    # :call-seq:
    #    link.for_uri  -> URI encoded string
    #
    # URI represent this JiakLink, i.e, a string suitable for inclusion in an
    # URI.
    def for_uri
      URI.encode(for_jiak.join(','))
    end

    # :call-seq:
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

    # :call-seq:
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
    def transform_args(b,k,t)
      b = b.name  if b.is_a? JiakBucket
      [b,k,t].map do |arg|
        arg = ANY  if arg.nil?
        unless arg.is_a? String
          raise JiakLinkException, "Link elements must be Strings."
        end
        value = arg.dup
        value.strip!
        value.empty? ? ANY : value
      end
    end
    
    def transform_arg(arg)
      arg = ANY  if arg.nil?
      unless arg.is_a? String
        raise JiakLinkException, "Link elements must be Strings."
      end
      value = arg.dup
      value.strip!
      value.empty? ? ANY : value
    end
  end
end
