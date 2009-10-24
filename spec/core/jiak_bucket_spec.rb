require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakBucket" do
  before do
    @name = 'test'
    @data_class = JiakDataHash.create(:f1,:f2)
    @params = {:reads => 1, :writes => 2, :durable_writes => 3, :waits => 4}
    @bucket = JiakBucket.new(@name,@data_class)
  end

  it "should respond to" do
    @bucket.should respond_to(:name,:data_class,:params,:schema)
    @bucket.should respond_to(:data_class=,:params=)
    @bucket.should respond_to(:eql?)

    @bucket.should_not respond_to(:name=)
  end

  it "should initialize with name and data class" do
    @bucket.name.should eql @name
    @bucket.data_class.should eql @data_class
    @bucket.params.should be_empty
  end

  it "should initialize with name, data class, and params" do
    bucket = JiakBucket.new('test',@data_class,@params)
    bucket.name.should eql @name
    bucket.data_class.should eql @data_class
    bucket.params.should have_exactly(4).items
    @params.each {|k,v| bucket.params[k].should == @params[k]}

    @params.delete(:writes)
    bucket = JiakBucket.new('test',@data_class,@params)
    bucket.params.should have_exactly(3).items
    bucket.params[:waits].should == @params[:waits]
  end

  it "should update the data class" do
    data_class = JiakDataHash.create(:g1)
    @bucket.data_class = data_class
    @bucket.data_class.should eql data_class
  end

  it "should update the params" do
    @bucket.params.should be_empty
    @bucket.params = @params
    @bucket.params.should eql @params
  end

  it "should validate name, data class, and params" do
    empty_name = lambda {JiakBucket.new("",@data_class)}
    empty_name.should raise_error(JiakBucketException,/Name.*empty/)

    empty_name = lambda {JiakBucket.new("  ",@data_class)}
    empty_name.should raise_error(JiakBucketException,/Name.*empty/)

    nil_name = lambda {JiakBucket.new(nil,@data_class)}
    nil_name.should raise_error(JiakBucketException,/Name.*nil/)

    bad_data_class = lambda {JiakBucket.new(@name,Hash)}
    bad_data_class.should raise_error(JiakBucketException,/JiakData/)

    bad_data_class = lambda {@bucket.data_class = Hash}
    bad_data_class.should raise_error(JiakBucketException,/JiakData/)

    params = @params
    params.delete(:writes)
    params[:write] = 2
    bad_params = lambda {JiakBucket.new(@name,@data_class,params)}
    bad_params.should raise_error(JiakBucketException,/params/)

    bad_params = lambda {@bucket.params = params}
    bad_params.should raise_error(JiakBucketException,/params/)
  end

  it "should provide the schema for the data class" do
    @bucket.schema.should eql @data_class.schema
  end

  it "should eql by state" do
    bucket = JiakBucket.new(@name,@data_class)
    bucket.should eql @bucket

    bucket = JiakBucket.new(@name.upcase,@data_class)
    bucket.should_not eql @bucket

    data_class = JiakDataHash.create(:g1)
    bucket = JiakBucket.new(@name,data_class)
    bucket.should_not eql @bucket

    bucket = JiakBucket.new(@name,@data_class,@params)
    bucket.should_not eql @bucket

    @bucket.params = @params
    bucket.should eql @bucket

    params = {:reads => @params[:reads]+1}
    bucket_1 = JiakBucket.new(@name,@data_class,@params)
    bucket_2 = JiakBucket.new(@name,@data_class,params)
    bucket_1.should_not eql bucket_2
  end

end
