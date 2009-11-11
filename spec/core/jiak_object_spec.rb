require File.dirname(__FILE__) + '/../spec_helper.rb'

DataObject = JiakDataHash.create(:f1,:f2,:f3)

describe "JiakObject" do
  before do
    @data = 
      DataObject.new(:f1 => 'f1',:f2 => ['a','b'], :f3 => {:f3_1 => 'f3_1'})
    @bucket_name = 'bucket'
    @bucket = JiakBucket.new(@bucket_name,DataObject)
    @key = 'hey'
    @l1 = JiakLink.new('l1b','l1k','l1t')
    @l2 = JiakLink.new('l2b','l2k','l2t')
    @links = [@l1,@l2]

    object = @data.to_jiak
    links = @links.map {|link| link.to_jiak}

    core = {
      :bucket => @bucket_name, :key => @key,
      :object => object, :links => links
    }
    full = core.merge(:vclock=>'vclock',:vtag=>'vtag',:lastmod=>'last mod')
    @core_json = core.to_json
    @full_json = full.to_json
    @object = JiakObject.new(:bucket => @bucket,
                             :key => @key,
                             :data => @data,
                             :links => @links)
  end

  it "should respond to" do
    JiakObject.should respond_to(:new,:from_jiak)

    @object.should respond_to(:bucket,:bucket=)
    @object.should respond_to(:key,:key=)
    @object.should respond_to(:data,:data=)
    @object.should respond_to(:links,:links=)
    @object.should respond_to(:riak,:riak=)
    @object.should respond_to(:local?)
    @object.should respond_to(:<<)
    @object.should respond_to(:==,:eql?)
    @object.should respond_to(:to_jiak)
  end

  it "should initialize with bucket, key and data" do
    @object.bucket.should eql @bucket
    @object.key.should eql @key
    @object.data.should be_a JiakData
    @object.data.should eql @data
    @object.links.should be_an Array
    @object.links.should eql @links
    
    jobj = JiakObject.new(:bucket => @bucket, :key => @key, :data => @data)
    jobj.bucket.should eql @bucket
    jobj.links.should be_empty
    jobj.local?.should be true
  end

  it "should allow nil, missing, blank or empty key" do
    [nil,'','  '].each do |key|
      JiakObject.new(:bucket => @bucket, :data => @data,
                     :key => key ).key.should be_empty
    end
    JiakObject.new(:bucket => @bucket, :data => @data).key.should be_empty
  end


  it "should initialize with specified links" do
    @object.links.should equal @links
  end

  it "should initialize from JSON" do
    [@core_json,@full_json].each do |json|
      jiak = JSON.parse(json)
      jobj = JiakObject.from_jiak(jiak,@bucket.data_class)
      jobj.bucket.should eql @object.bucket
      jobj.key.should eql @object.key
      jobj.data.f1.should eql @data.f1
      jobj.data.f2.should eql @data.f2
      jobj.data.f3['f3_1'].should eql @data.f3[:f3_1]

      jobj.links.size.should == @object.links.size
      jlinks = jobj.links
      olinks = @object.links
      same = jlinks.reduce(true) {|same,value| same && olinks.include?(value)}
      same.should be true
    end

    jiak = JSON.parse(@full_json)
    jobj = JiakObject.from_jiak(jiak,@bucket.data_class)
    jobj.riak[:vclock].should eql 'vclock'
    jobj.riak[:vtag].should eql 'vtag'
    jobj.riak[:lastmod].should eql 'last mod'
  end

  it "should raise JiakObjectException for nil bucket" do
    nil_bucket = lambda {JiakObject.new(:bucket => nil,:data_obect => @data)}
    nil_bucket.should raise_error(JiakObjectException)
    no_bucket = lambda {JiakObject.new(:data_obect => @data)}
    no_bucket.should raise_error(JiakObjectException)
  end

  it "should raise JiakObjectException if object not a JiakData" do
    bad_data = lambda {JiakObject.new(:bucket=>@bucket,:data=>'a')}
    bad_data.should raise_error(JiakObjectException,/JiakData/)
    no_data = lambda {JiakObject.new(:bucket=>@bucket)}
    no_data.should raise_error(JiakObjectException,/JiakData/)
  end

  it "should raise JiakObjectException if link not an Array" do
    link_not_array = lambda {JiakObject.new(:bucket => @bucket,
                                            :data => @data,
                                            :links =>"l")}
    link_not_array.should raise_error(JiakObjectException,/array/)
  end

  it "should raise JiakObjectException if each link is not a JiakLink" do
    links = [@l1,'l',@l2]
    bad_link = lambda {JiakObject.new(:bucket => @bucket,
                                      :data => @data,
                                      :links => [@l1,'l',@l2])}
    bad_link.should raise_error(JiakObjectException,/JiakLink/)
  end
  
  it "should convert to JSON" do
    json = @object.to_jiak.to_json
    json.should eql @core_json

    parsed = JSON.parse(json)
    parsed['bucket'].should eql @bucket_name
    parsed['key'].should eql @key
    parsed['object']['f1'].should eql @data.f1
    parsed['object']['f2'].should eql @data.f2
    parsed['object']['f3']['f3_1'].should eql @data.f3[:f3_1]
    @links.each_with_index do |link,ndx|
      parsed['links'][ndx].should eql link.to_jiak
    end
  end

  it "should allow attribute updates" do
    bucket_name = 'new bucket'
    bucket = JiakBucket.new(bucket_name,DataObject)
    @object.bucket = bucket
    @object.bucket.should eql bucket

    key = 'new key'
    @object.key = key
    @object.key.should eql key

    object = DataObject.new(:f1 => 'new f1',:f2 => [], :f3 => 6)
    @object.data.should_not eql object
    @object.data = object
    @object.data.should eql object

    links = [JiakLink.new('c','b','a')]
    @object.links = links
    @object.links.should eql links
    
    riak = {:vclock => 'VCLOCK', :vtag => 'VTAG', :lastmod => 'LASTMOD'}
    @object.riak = riak
    @object.riak.should eql riak

    @object.riak = nil
    @object.riak.should be nil

    bad_bucket = lambda {@object.bucket = 'bucket'}
    bad_bucket.should raise_error(JiakObjectException,/Bucket/)

    bad_key = lambda {@object.key = @bucket}
    bad_key.should raise_error(JiakObjectException,/Key/)

    bad_object = lambda {@object.data = @bucket}
    bad_object.should raise_error(JiakObjectException,/Data/)
    
    bad_links = lambda {@object.links = @bucket}
    bad_links.should raise_error(JiakObjectException,/Links/)
  end

  it "should add a link" do
    jiak_link = JiakLink.new('a','b','c')
    @object.links.should_not include jiak_link

    size = @links.size
    @object << jiak_link
    @object.links.should have_exactly(size+1).items
    @object.links.should include jiak_link
  end
  
  it "should ignore a duplicate link" do
    size = @object.links.size
    @object << @l1
    @object.links.should have_exactly(size).items
  end

  it "should chain link adds" do
    size = @object.links.size
    jiak_link = JiakLink.new('a','b','c')
    @object << @l2 << jiak_link
    @object.links.should have_exactly(size+1).items
  end

  it "should raise exception if adding a non-JiakLink" do
    bad_link = lambda {@object << ['l']}
    bad_link.should raise_error(JiakObjectException,/JiakLink/)
  end

  it "should eql an equal JiakObject" do
    jobj = JiakObject.new(:bucket => @bucket, :key => @key,
                          :data => @data, :links => @links)
    @object.should eql jobj
    @object.should ==  jobj
  end

end
