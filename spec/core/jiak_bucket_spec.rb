require File.dirname(__FILE__) + '/../spec_helper.rb'

DataHash = JiakDataHash.create(:f1,:f2)
DataG1 = JiakDataHash.create(:g1)

describe "JiakBucket" do
  before do
    @name = 'test'
    @bucket = JiakBucket.create('test',DataHash)
  end

  it "should respond to" do
    JiakBucket.should respond_to(:create)
    JiakBucket.should_not respond_to(:new)
    
    @bucket.should respond_to(:name,:data_class,:schema)
    @bucket.should respond_to(:data_class=)
    @bucket.should respond_to(:schema)
    @bucket.should respond_to(:eql?,:==)

    @bucket.should_not respond_to(:name=)
  end

  it "should initialize with name and data class" do
    @bucket.name.should eql @name
    @bucket.data_class.should eql DataHash
  end

  it "should update the data class" do
    @bucket.data_class = DataG1
    @bucket.data_class.should eql DataG1
  end

  it "should validate name and data class" do
    empty_name = lambda {JiakBucket.create("",DataHash)}
    empty_name.should raise_error(JiakBucketException,/Name.*empty/)

    empty_name = lambda {JiakBucket.create("  ",DataHash)}
    empty_name.should raise_error(JiakBucketException,/Name.*empty/)

    nil_name = lambda {JiakBucket.create(nil,DataHash)}
    nil_name.should raise_error(JiakBucketException,/Name.*nil/)

    bad_data_class = lambda {JiakBucket.create(@name,Hash)}
    bad_data_class.should raise_error(JiakBucketException,/JiakData/)

    bad_data_class = lambda {@bucket.data_class = Hash}
    bad_data_class.should raise_error(JiakBucketException,/JiakData/)
  end

  it "should provide the schema for the data class" do
    @bucket.schema.should eql DataHash.schema
  end

  it "should be comparable via eql and ==" do
    bucket = JiakBucket.create(@name,DataHash)
    bucket.should eql @bucket
    bucket.should == @bucket
  end

end
