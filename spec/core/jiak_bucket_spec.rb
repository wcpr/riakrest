require File.dirname(__FILE__) + '/../spec_helper.rb'

F1F2 = JiakDataFields.create :f1, :f2
G1   = JiakDataFields.create :g1

describe "JiakBucket" do
  before do
    @name = 'bucket_name'
    @data_class = F1F2
    @bucket = JiakBucket.new(@name,@data_class)
  end

  it "should respond to" do
    @bucket.should respond_to(:name,:data_class,:schema)
    @bucket.should respond_to(:name=,:data_class=)
    @bucket.should respond_to(:eql?)
  end

  it "should initialize with name and data class" do
    @bucket.name.should eql @name
    @bucket.data_class.should eql @data_class
  end

  it "should initialize with name and data class" do
    bucket = JiakBucket.new(@name,@data_class)
    bucket.name.should eql @name
    bucket.data_class.should eql @data_class
  end

  it "should update the name and data class" do
    name = 'new_bucket_name'
    @bucket.name = name
    @bucket.name.should eql name

    data_class = G1
    @bucket.data_class = data_class
    @bucket.data_class.should eql data_class
  end

  it "should validate name and data class" do
    empty_name = lambda {JiakBucket.new("",@data_class)}
    empty_name.should raise_error(JiakBucketException,/Name.*empty/)

    empty_name = lambda {JiakBucket.new("  ",@data_class)}
    empty_name.should raise_error(JiakBucketException,/Name.*empty/)

    nil_name = lambda {JiakBucket.new(nil,@data_class)}
    nil_name.should raise_error(JiakBucketException,/Name.*string/)

    bad_data_class = lambda {JiakBucket.new(@name,Hash)}
    bad_data_class.should raise_error(JiakBucketException,/JiakData/)

    bad_data_class = lambda {@bucket.data_class = Hash}
    bad_data_class.should raise_error(JiakBucketException,/JiakData/)
  end

  it "should provide the schema for the data class" do
    @bucket.schema.should eql @data_class.schema
  end

  it "should eql by state" do
    bucket = JiakBucket.new(@name,@data_class)
    bucket.should eql @bucket

    bucket = JiakBucket.new(@name.upcase,@data_class)
    bucket.should_not eql @bucket

    data_class = G1
    bucket = JiakBucket.new(@name,data_class)
    bucket.should_not eql @bucket
  end

end
