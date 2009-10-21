module RiakRest

  # A bucket on a Jiak server. In Riak parlance, buckets just have a name. In
  # RiakRest, buckets also have an associated JiakData class. This data class
  # is used to inflate the user-defined data into JiakData objects when
  # retrieved from the Jiak server.
  class JiakBucket

    attr_reader :name
    attr_accessor :data_class

    private_class_method :new

    def initialize(name,data_class)  # nodoc:
      @name = name
      @data_class = data_class
    end

    # call-seq:
    #   JiakBucket.create(name,data_class)  -> JiakBucket
    #
    # Create a bucket for use in Jiak interaction.
    #
    # Raise JiakBucketException if the bucket name is not a non-empty string or
    # the data class is not a JiakData.
    def self.create(name,data_class)
      new(transform_name(name),check_data_class(data_class))
    end

    # call-seq:
    #   bucket.data_class = data_class
    #
    # Set the class for the data to be stored or retrieved from the bucket.
    #
    # Raise JiakBucketException if the data class is not a JiakData.
    def data_class=(data_class)
      @data_class = JiakBucket.check_data_class(data_class)
    end

    # call-seq:
    #   bucket.schema  -> JiakSchema
    #
    # Gets the data schema for this bucket. This call does not access the
    # server, but rather returns the schema of the current data class
    # associated with the bucket. This association is required to establish the
    # Jiak server schema in the first place, so as long as the Jiak server
    # schema has not be altered by another call to JiakClient#set_schema the
    # information returned via this call will be current.
    def schema
      data_class.schema
    end

    # call-seq:
    #    jiak_bucket.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <i>jiak_bucket</i> and <i>other</i> contain
    # the same attribute values.
    def eql?(other)
      (other.name.eql?(@name) &&
       other.data_class.eql?(@data_class)) rescue false
    end

    # call-seq:
    #    jiak_bucket == other -> true or false
    #
    # Equality -- JiakBuckets are equal if they contain the same attribute
    # values.
    def ==(other)
      (other.name == @name &&
       other.data_class == @data_class) rescue false
    end

    private
    def self.transform_name(name)
      raise JiakBucketException, "Name cannot be nil" if name.nil?
      unless name.is_a?(String)
        raise JiakBucketException, "Name must be a String"
      end
      name.strip!
      raise JiakBucketException, "Name cannot be empty" if name.empty?
      name
    end

    def self.check_data_class(data_class)
      unless data_class.include?(JiakData)
        raise JiakBucketException, "Data class must be type of JiakData."
      end
      data_class
    end
  end


end
