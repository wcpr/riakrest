module RiakRest

  # Data is stored on the Jiak server by key under a bucket. During Jiak
  # interaction, the bucket on the server has an associated schema which
  # determines permissible data interaction. See JiakSchema for a discussion of
  # schemas in Jiak. Since the bucket schema can be changed dynamically,
  # schemas can be viewed more as a loose type system rather than an onerous
  # restriction.
  #
  # In RiakRest buckets have an associated JiakData class, and each JiakData
  # class has an associated JiakSchema. These associations facility setting and
  # maintaining the current schema in use for a Jiak bucket. Dynamically
  # changing the bucket schema means you can have either homogeneous (simplest)
  # or heterogenous data in a single Jiak server bucket. It also means you can
  # define multiple JiakData classes that effectively present different "views"
  # (via schemas) into the same data stored on the Jiak server. These classes
  # act like types that can determine which fields are accessible for reading
  # and writing data. The JiakData class associated with a bucket is also used
  # to marshal user-defined data going to and from the Jiak server.
  #
  # JiakResource greatly eases the bookkeeping necessary for heterogenous, as
  # well as homogenous, data interaction with the Jiak server.
  class JiakBucket

    attr_reader :name, :schema
    attr_accessor :data_class, :params

    private_class_method :new

    def initialize(name,data_class,params={})  # nodoc:
      @name = name
      @data_class = data_class
      @params = params
    end

    # :call-seq:
    #   JiakBucket.create(name,data_class,params={})  -> JiakBucket
    #
    # Create a bucket for use in Jiak interaction.
    #
    # <code>name</code> and <code>data_class</code> are mandatory. Valid keys
    # for the optional <code>params</code> hash are <code>:reads, :writes,
    # :durable_writes, :waits</code>. See JiakClient#store, JiakClient#get, and
    # JiakClient#delete for discriptions of these parameters.
    #
    # Raise JiakBucketException if the bucket name is not a non-empty string or
    # the data class has not included the JiakData module.
    def self.create(name,data_class,params={})
      params = check_params(params)  unless params.empty?
      new(transform_name(name),check_data_class(data_class),params)
    end

    # :call-seq:
    #   bucket.data_class = data_class
    #
    # Set the class for the data to be stored or retrieved from the bucket.
    #
    # Raise JiakBucketException if the data class is not a JiakData.
    def data_class=(data_class)
      @data_class = self.class.check_data_class(data_class)
    end

    # :call-seq:
    #   bucket.params = params
    #
    # Set default params for Jiak client requests. See JiakBucket#create for
    # valid parameters.
    #
    def params=(params)
      @params = self.class.check_params(params)
    end

    # :call-seq:
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

    # :call-seq:
    #    jiak_bucket.eql?(other) -> true or false
    #
    # Returns <code>true</code> if <i>jiak_bucket</i> and <i>other</i> contain
    # the same attribute values.
    def eql?(other)
      (@name.eql?(other.name) &&
       @data_class.eql?(other.data_class) &&
       @params.eql?(other.params)) rescue false
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

    def self.check_params(params)
      valid = [:reads,:writes,:durable_writes,:waits]
      err = params.select {|k,v| !valid.include?(k)}
      unless err.empty?
        raise JiakBucketException, "unrecognized request params: #{err.keys}"
      end
      params
    end
  end

end
