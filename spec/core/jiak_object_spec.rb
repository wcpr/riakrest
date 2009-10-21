require File.dirname(__FILE__) + '/../spec_helper.rb'

DataObject = JiakDataHash.create(:f1,:f2,:f3)

describe "JiakObject" do
  before do
    @data = 
      DataObject.new(:f1 => 'f1',:f2 => ['a','b'], :f3 => {:f3_1 => 'f3_1'})
    @bucket_name = 'test'
    @bucket = JiakBucket.create(@bucket_name,DataObject)
    @key = 'hey'
    @l1 = JiakLink.create({:bucket => 'l1b'})
    @l2 = JiakLink.create(['l2b', 'l2t', 'l2a'])
    @links = [@l1,@l2]

    object = @data.for_jiak
    links = @links.map {|link| link.for_jiak}

    core = {
      :bucket => @bucket_name, :key => @key,
      :object => object, :links => links
    }
    full = core.merge(:vclock=>'vclock',:vtag=>'vtag',:lastmod=>'last mod')
    @core_json = core.to_json
    @full_json = full.to_json
    @object = JiakObject.create(:bucket => @bucket,
                                :key => @key,
                                :data => @data,
                                :links => @links)
  end

  it "should respond to" do
    JiakObject.should respond_to(:create,:from_jiak)
    JiakObject.should_not respond_to(:new)

    @object.should respond_to(:bucket,:bucket=)
    @object.should respond_to(:key,:key=)
    @object.should respond_to(:data,:data=)
    @object.should respond_to(:links,:links=)
    @object.should respond_to(:<<)
    @object.should respond_to(:eql?, :to_jiak)
  end

  it "should initialize with bucket, key and data" do
    @object.bucket.should eql @bucket
    @object.key.should eql @key
    @object.data.should be_a JiakData
    @object.data.should eql @data
    @object.links.should be_an Array
    @object.links.should eql @links
    
    jobj = JiakObject.create(:bucket => @bucket, :key => @key,
                             :data => @data)
    jobj.bucket.should eql @bucket
    jobj.links.should be_empty
  end

  it "should allow nil, missing, blank or empty key" do
    JiakObject.create(:bucket => @bucket,:data => @data,
                      :key => nil).key.should be_empty
    JiakObject.create(:bucket => @bucket,
                      :data => @data).key.should be_empty
    JiakObject.create(:bucket => @bucket,:data => @data,
                      :key => '').key.should be_empty
    JiakObject.create(:bucket => @bucket,:data => @data,
                      :key => '  ').key.should be_empty
  end


  it "should initialize with specified links" do
    @object.links.should equal @links
  end

  it "should initialize from JSON" do
    [@core_json,@full_json].each do |json|
      jobj = JiakObject.from_jiak(json,@bucket.data_class)
      jobj.bucket.should eql @object.bucket
      jobj.key.should eql @object.key
      jobj.data.f1.should eql @data.f1
      jobj.data.f2.should eql @data.f2
      jobj.data.f3['f3_1'].should eql @data.f3[:f3_1]
      same_elements(jobj.links,@object.links).should be true
    end

    jobj = JiakObject.from_jiak(@full_json,@bucket.data_class)
    jobj.riak[:vclock].should eql 'vclock'
    jobj.riak[:vtag].should eql 'vtag'
    jobj.riak[:lastmod].should eql 'last mod'
  end

  it "should raise JiakObjectException for nil bucket" do
    nil_bucket = lambda {JiakObject.create(:bucket => nil,
                                           :data_obect => @data)}
    nil_bucket.should raise_error(JiakObjectException)
    no_bucket = lambda {JiakObject.create(:data_obect => @data)}
    no_bucket.should raise_error(JiakObjectException)
  end

  it "should raise JiakObjectException if object not a JiakData" do
    bad_data = lambda {JiakObject.create(:bucket=>@bucket,:data=>'a')}
    bad_data.should raise_error(JiakObjectException,/JiakData/)
    no_data = lambda {JiakObject.create(:bucket=>@bucket)}
    no_data.should raise_error(JiakObjectException,/JiakData/)
  end

  it "should raise JiakObjectException if link not an Array" do
    link_not_array = lambda {JiakObject.create(:bucket => @bucket,
                                               :data => @data,
                                               :links =>"l")}
    link_not_array.should raise_error(JiakObjectException,/Array/)
  end

  it "should raise JiakObjectException if each link is not a JiakLink" do
    links = [@l1,'l',@l2]
    bad_link = lambda {JiakObject.create(:bucket => @bucket,
                                         :data => @data,
                                         :links => [@l1,'l',@l2])}
    bad_link.should raise_error(JiakObjectException,/JiakLink/)
  end
  
  it "should convert to JSON" do
    json = @object.to_jiak
    json.should eql @core_json

    parsed = JSON.parse(json)
    parsed['bucket'].should eql @bucket_name
    parsed['key'].should eql @key
    parsed['object']['f1'].should eql @data.f1
    parsed['object']['f2'].should eql @data.f2
    parsed['object']['f3']['f3_1'].should eql @data.f3[:f3_1]
    @links.each_with_index do |link,ndx|
      parsed['links'][ndx].should eql link.for_jiak
    end
  end

  it "should allow object updates" do
    object = DataObject.new(:f1 => 'new f1',:f2 => [], :f3 => 6)
    @object.data.should_not eql object
    @object.data = object
    @object.data.should eql object
  end

  it "should add a link" do
    jiak_link3 = JiakLink.create(['a','b','c'])
    @object.links.should_not include jiak_link3

    size = @links.size
    @object << jiak_link3
    @object.links.should have_exactly(size+1).items
    @object.links.should include jiak_link3

    jiak_link4 = JiakLink.create(['d','e','f'])
    @object.links.should_not include jiak_link4
    @object << jiak_link4
    @object.links.should have_exactly(size+2).items
    @object.links.should include jiak_link4
  end

  it "should raise exception if adding a non-JiakLink" do
    bad_link = lambda {@object << ['l']}
    bad_link.should raise_error(JiakObjectException,/JiakLink/)
  end

  it "should eql an equal JiakObject" do
    jobj = JiakObject.create(:bucket => @bucket,
                              :key => @key,
                              :data => @data,
                              :links => @links)
    @object.should eql jobj
  end

end
