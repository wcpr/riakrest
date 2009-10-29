module RiakRest

  # Represents a link used to query linked objects in Jiak. Links are
  # established using a JiakLink and queried using a QueryLink. The structures
  # are very similar but significantly different.
  #
  # ===Usage
  # <code>
  #   link = QueryLink.new('people','parent')
  #   link = QueryLink.new(['children','odd','_'])
  #   link = QueryLink.new('blogs',nil,QueryLink::ANY)
  # </code>
  class QueryLink

    attr_accessor :bucket, :tag, :acc

    # Jiak (erlang) wildcard character (atom)
    ANY = '_'

    # :call-seq:
    #   QueryLink.new(*args)  -> QueryLink
    #
    # Create a link from argument array. Missing, nil, or empty string values
    # are set to QueryLink::ANY.
    #
    # ====Examples
    # The following create QueryLinks with the shown equivalent array structure:
    # <code>
    #   QueryLink.new                       # => ['_','_','_']
    #   QueryLink.new 'b'                   # => ['b','_','_']
    #   QueryLink.new 'b','t'               # => ['b','t','_']
    #   QueryLink.new 'b','t','a'           # => ['b','t','a']
    #
    #   QueryLink.new []                    # => ['_','_','_']
    #   QueryLink.new ['b']                 # => ['b','_','_']
    #   QueryLink.new ['b','t']             # => ['b','t','_']
    #   QueryLink.new ['b','t','a']         # => ['b','t','a']
    #
    #   QueryLink.new ['',nil,' ']          # => ['_','_','_']
    # </code>
    #
    # Passing another QueryLink as an argument makes a copy of that
    # link. Passing a JiakBucket in the first (bucket) position uses the name
    # field of that JiakBucket.
    def initialize(*args)
      case args.size
      when 0
        bucket = tag = acc = ANY
      when 1
        if args[0].is_a? String
          bucket = args[0]
          tag = acc = ANY
        elsif args[0].is_a? QueryLink
          bucket, tag, acc = args[0].bucket, args[0].tag, args[0].acc
        elsif args[0].is_a? Array
          bucket, tag, acc = args[0][0], args[0][1], args[0][2]
        else
          raise QueryLinkException, "argument error"
        end
      when 2
        bucket, tag = args[0], args[1]
        acc = ANY
      when 3
        bucket, tag, acc = args[0], args[1], args[2]
      else
        raise QueryLinkException, "too many arguments, (#{args.size} for 3)"
      end
      
      @bucket, @tag, @acc  = transform_args(bucket,tag,acc)
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
    #   link.tag = tag
    #
    # Set the tag field.
    def tag=(tag)
      @tag = transform_arg(tag)
    end

    # :call-seq:
    #   link.acc = acc
    #
    # Set the acc field.
    def acc=(acc)
      @acc = transform_arg(acc)
    end

    # :call-seq:
    #    link.for_uri  -> URI encoded string
    #
    # URI represent this QueryLink, i.e, a string suitable for inclusion in an
    # URI.
    def for_uri
      URI.encode([@bucket,@tag,@acc].join(','))
    end

    # :call-seq:
    #    link == other -> true or false
    #
    # Equality -- QueryLinks are equal if they contain the same attribute
    # values.
    def ==(other)
      (@bucket == other.bucket &&
       @tag    == other.tag    &&
       @acc    == other.acc) rescue false
    end

    # :call-seq:
    #    link.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <code>other</code> is a QueryLink with the
    # same attribute values.
    def eql?(other)
      other.is_a?(QueryLink) &&
        @bucket.eql?(other.bucket) &&
        @tag.eql?(other.tag) &&
        @acc.eql?(other.acc)
    end

    def hash    # :nodoc:
      @bucket.name.hash + @tag.hash + @acc.hash
    end

    # String representation of this QueryLink.
    def to_s
      "[#{bucket},#{tag},#{acc}]"
    end

    def transform_args(b,t,a)
      b = b.name  if b.is_a? JiakBucket
      [transform_arg(b),transform_arg(t),transform_arg(a)]
    end
    private :transform_args
    
    def transform_arg(arg)
      arg = ANY  if arg.nil?
      unless arg.is_a? String
        raise QueryLinkException, "Link elements must be Strings."
      end
      value = arg.dup
      value.strip!
      value.empty? ? ANY : value
    end
    private :transform_arg
  end
end

