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

    # :call-seq:
    #   JiakLink.new(bucket,key,tag)  -> JiakLink
    #
    # Create a link to a bucket/key data designated by tag. Bucket can be
    # either a JiakBucket or a string bucket name; key and tag must both be
    # strings.
    #
    def initialize(*args)
      case args.size
      when 1
        if args[0].is_a? Array
          bucket, key, tag = args[0][0], args[0][1], args[0][2]
        elsif args[0].is_a? JiakLink
          bucket, key, tag = args[0].bucket, args[0].key, args[0].tag
        else
          raise JiakLinkException, "argument error"
        end
      when 3
        bucket, key, tag = args[0], args[1], args[2]
      else
        raise JiakLinkException, "argument error"
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
    #    link == other -> true or false
    #
    # Equality -- JiakLinks are equal if they contain the same attribute values.
    def ==(other)
      (@bucket == other.bucket &&
       @key    == other.key    &&
       @tag    == other.tag) rescue false
    end

    # :call-seq:
    #    eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a JiakLink with the
    # same attribute values.
    def eql?(other)
      other.is_a?(JiakLink) &&
        @bucket.eql?(other.bucket) &&
        @key.eql?(other.key) &&
        @tag.eql?(other.tag)
    end

    def hash    # :nodoc:
      @bucket.hash + @key.hash + @tag.hash
    end

    # String representation of this JiakLink.
    def to_s
      '["'+@bucket+'","'+@key+'","'+@tag+'"]'
    end

    def transform_args(b,k,t)
      b = b.name  if b.is_a? JiakBucket
      [transform_arg(b),transform_arg(k),transform_arg(t)]
    end
    private :transform_args
    
    def transform_arg(arg)
      unless arg.is_a? String
        raise JiakLinkException, "Link elements must be Strings."
      end
      value = arg.dup
      value.strip!
      if value.empty?
        raise JiakLinkException, "Link elements can't be empty."
      end
      value
    end
    private :transform_args

  end
end
