require File.dirname(__FILE__) + '/../spec_helper.rb'

class FooBarBaz  # :nodoc:
  include JiakData

  jattr_accessor :foo, :bar
  require :foo
  allow   :baz
end

describe "JiakClient" do
  before do
    @base_uri = 'http://127.0.0.1:8002/jiak/'
    @client = JiakClient.new(@base_uri)
    @params = {:reads => 1, :writes => 2, :durable_writes => 3, :waits => 4}
    @opts = @params.merge({:proxy => 'proxy_uri'})
  end

  it "should respond to" do
    @client.should respond_to(:set_schema,:schema,:keys)
    @client.should respond_to(:proxy,:proxy=)
    @client.should respond_to(:params,:set_params,:params=)
    @client.should respond_to(:get,:store,:delete,:walk)
    @client.should respond_to(:==,:eql?)
  end

  it "should default to base URI" do
    @client.server.should match @base_uri
  end

  it "should allow specified base URI" do
    base_uri = 'http://localhost:1234/tmp/'
    client = JiakClient.new base_uri
    client.server.should match base_uri
  end

  it "should equal another JiakClient with the same URI" do
    client = JiakClient.new @base_uri
    client.should eql @client
    client.should ==  @client
  end

  it "should initialize proxy and params" do
    client = JiakClient.new(@base_uri,:proxy => 'proxy_uri',:reads => 1)
    client.proxy.should eql 'proxy_uri'
    client.params[:reads].should == 1

    client = JiakClient.new(@base_uri,@opts)
    client.proxy.should eql 'proxy_uri'
    client.params.should have_exactly(4).items
    @params.each {|k,v| client.params[k].should == @params[k]}
    
    @opts.delete(:proxy)
    @opts.delete(:writes)
    client = JiakClient.new(@base_uri,@opts)
    client.params.should have_exactly(3).items
    client.proxy.should be nil
    client.params[:writes].should be nil

    @opts[:junk] = 'junk'
    bad_opts = lambda {JiakClient.new(@base_uri,@opts)}
    bad_opts.should raise_error(JiakClientException,/option/)
  end

  it "should update proxy and params" do
    @client.proxy = 'another_proxy'
    @client.proxy.should eql 'another_proxy'

    @client.params = @params
    @params.each {|k,v| @client.params[k].should == @params[k]}

    @client.set_params(:writes => 1, :waits => nil)
    params = @client.params
    params[:reads].should eql 1
    params[:writes].should eql 1
    params[:durable_writes].should eql 3
    params[:waits].should eql nil

    bad_opts = lambda {@client.set_params(:junk => 'junk')}
    bad_opts.should raise_error(JiakClientException,/option/)
    
    @params[:junk] = 'junk'
    bad_opts = lambda {@client.params = @params}
    bad_opts.should raise_error(JiakClientException,/option/)
  end
end

describe "JiakClient URI handling" do
  before do
    @base_uri = 'http://127.0.0.1:8002/jiak/'
    @client = JiakClient.new @base_uri
    @bucket = JiakBucket.new('uri_bucket',FooBarBaz)
    @key = 'uri_key'
  end
end

describe "JiakClient processing" do
  before do
    @base_uri = 'http://127.0.0.1:8002/jiak/'
    @client = JiakClient.new @base_uri
  end

  describe "for buckets" do
    before do
      @bucket_name = 'bucket_1'
      @bucket = JiakBucket.new(@bucket_name,FooBarBaz)
      @client.set_schema(@bucket)
    end

    it "should create and fetch a bucket schema" do
      schema = @client.schema(@bucket)
      
      ['allowed_fields',
       'required_fields',
       'read_mask',
       'write_mask'].each do |fields|
        schema_fields = schema.send("#{fields}")
        fbb_fields = FooBarBaz.schema.send("#{fields}")
        schema_fields.same_fields?(fbb_fields).should be true
      end
    end

    it "should update an existing bucket schema" do
      FooBarBazBuz = JiakDataFields.create(:foo,:bar,:baz,:buz)
      @client.set_schema(JiakBucket.new(@bucket_name,FooBarBazBuz))
      
      resp_schema = @client.schema(@bucket)
      resp_schema.allowed_fields.should include :buz
      resp_schema.required_fields.should be_empty
      resp_schema.read_mask.should include :baz
      resp_schema.write_mask.should include :baz

    end

    it "should get a list of keys for a bucket" do
      arr = [{:key=>'key1',:dobj=>FooBarBaz.new(:foo=>'v1')},
             {:key=>'key2',:dobj=>FooBarBaz.new(:foo=>'v21',:bar=>'v22')},
             {:key=>'',:dobj=>FooBarBaz.new(:foo=>'v3')}]
      keys = arr.map do |hsh|
        jo = JiakObject.new(:bucket => @bucket,
                            :key => hsh[:key],
                            :data => hsh[:dobj])
        @client.store(jo)
      end
      srv_keys = @client.keys(@bucket)
      keys.each {|key| srv_keys.should include key}
    end

    it "should encode odd bucket strings" do
      bucket_name = "# <& %"
      bucket = JiakBucket.new(bucket_name,FooBarBaz)
      @client.set_schema(bucket)
      schema = @client.schema(@bucket)
      FooBarBaz.schema.read_mask.same_fields?(schema.read_mask).should be true
    end
  end

  describe "for CRUD" do
    before do
      @bucket = JiakBucket.new('bucket_2',FooBarBaz)
      @client.set_schema(@bucket)
      @data = FooBarBaz.new(:foo => 'foo val')
    end

    describe "storage" do
      it "should store a JiakObject by the specified key" do
        key = 'store_key_1'
        jobj = JiakObject.new(:bucket => @bucket, :key => key, :data => @data)
        resp = @client.store(jobj)
        resp.should eql key
      end

      it "should store a JiakObject w/o a key" do
        jobj = JiakObject.new(:bucket => @bucket, :data => @data)
        resp = @client.store(jobj)
        resp.should_not be_empty
      end

      it "should return a JiakObject at time of storage" do
        key = 'store_key_2'
        jobj = JiakObject.new(:bucket => @bucket, :key => key, :data => @data)
        resp = @client.store(jobj,{:return => :object})
        resp.should be_a JiakObject
        resp.bucket.should eql @bucket
        resp.key.should eql key
        resp.data.should be_a FooBarBaz

        jobj = JiakObject.new(:bucket => @bucket, :data => @data)
        jobj.local?.should be true
        resp = @client.store(jobj,{:return => :object})
        resp.should be_a JiakObject
        resp.key.should_not be_nil
        resp.data.should be_a FooBarBaz

        jobj.local?.should be true
        resp.local?.should be false
      end
      
      it "should handle odd key values" do
        key = '$ p @ c #'
        jobj = JiakObject.new(:bucket => @bucket, :key => key, :data => @data)
        resp_key = @client.store(jobj)
        resp_key.should eql key
      end
    end

    describe "fetching" do
      it "should get a previously stored JiakObject" do
        key = 'fetch_key_1'
        jobj = JiakObject.new(:bucket => @bucket, :key => key, :data => @data)
        @client.store(jobj)

        fetched = @client.get(@bucket,key)
        fetched.should be_a JiakObject
        fetched.bucket.should eql @bucket
        fetched.key.should eql key
        fetched.data.should eql jobj.data

        jobj = JiakObject.new(:bucket => @bucket, :key => key, :data => @data)
        key = @client.store(jobj)
        fetched = @client.get(@bucket,key)
        fetched.should be_a JiakObject
      end

      it "should raise JiakResourceNotFound for a non-existent key" do
        get_nope = lambda {@client.get(@bucket,'nope')}
        get_nope.should raise_error(JiakResourceNotFound)
      end
    end

    describe "updating" do
      it "should update a previously stored JiakObject" do
        jobj =
          @client.store(JiakObject.new(:bucket => @bucket, :data => @data),
                        {:return => :object})
        
        jobj.data.should eql @data
        [:vclock,:vtag,:lastmod].each do |field|
          jobj.riak.should include field
          jobj.riak[field].should be_a String
          jobj.riak[field].should_not be_empty
        end

        updated_data = FooBarBaz.new(:foo => 'new val')
        jobj.data = updated_data
        updated_object = 
          @client.store(jobj,{:return => :object})
        updated_data = updated_object.data
        updated_data.should_not eql @data
        updated_data.foo.should eql 'new val'
        updated_object.riak[:vclock].should_not eql jobj.riak[:vclock]
        updated_object.riak[:vtag].should_not eql jobj.riak[:vtag]
      end
    end

    describe "deleting" do
      it "should remove a previously stored JiakObject" do
        key = 'delete_key_1'
        jobj = JiakObject.new(:bucket => @bucket, :key => key, :data => @data)
        @client.store(jobj)

        @client.delete(@bucket,key).should be true
        get_deleted = lambda {@client.get(@bucket,key)}
        get_deleted.should raise_error(JiakResourceNotFound)
      end
    end
  end

end

class PersonData
  include JiakData
  jattr_accessor :name
end

describe "JiakClient links" do
  before do
    @base_uri = 'http://127.0.0.1:8002/jiak/'
    @client = JiakClient.new @base_uri

    @p_bucket = JiakBucket.new('parent',PersonData)
    @c_bucket = JiakBucket.new('child',PersonData)
    @client.set_schema(@p_bucket)
    @client.set_schema(@c_bucket)
  end

  it "should add links and walk the resulting structure" do
    parent_children = {
      'p1' => ['c1','c2'],
      'p2' => ['c2','c3','c4'],
      'p3' => ['c4','c5','c6'],
      'p4' => ['c5','c6'],
      'p5' => ['c7']
    }

    # invert the p/c relationships
    child_parents = parent_children.inject({}) do |build, (p,cs)|
      cs.each do |c|
        build[c] ? build[c] << p : build[c] = [p]
      end
      build
    end

    # for each p/c relation
    #  - create p and c (when necessary)
    #  - add links for p -> c and c -> p
    parent_children.each do |p_name,c_names|
      p_data = PersonData.new(:name => p_name)
      p_obj = JiakObject.new(:bucket => @p_bucket,
                             :key => p_name,
                             :data => p_data)
      parent = @client.store(p_obj,:return => :object)
      p_link = JiakLink.new(@p_bucket,parent.key,'parent')
      c_names.each do |c_name|
        begin
          child = @client.get(@c_bucket,c_name)
        rescue JiakResourceNotFound
          c_data = PersonData.new(:name => c_name)
          c_obj = JiakObject.new(:bucket => @c_bucket,
                                 :key => c_name,
                                 :data => c_data)
          child = @client.store(c_obj, :return => :object)
        end
        c_link = JiakLink.new(@c_bucket,child.key,'child')
        child << p_link
        @client.store(child)
        parent << c_link
      end
      @client.store(parent)
    end

    # get the number of links in the p's
    p1,p2,p3,p4,p5 = parent_children.keys.map {|p| @client.get(@p_bucket,p)}
    [p1,p4].each {|p| p.links.should have_exactly(2).items}
    [p2,p3].each {|p| p.links.should have_exactly(3).items}
    p5.links.should have_exactly(1).item

    # get the number of links in the c's
    c1,c2,c3,c4,c5,c6,c7 = child_parents.keys.map {|c| @client.get(@c_bucket,c)}
    [c1,c3,c7].each {|c| c.links.should have_exactly(1).items}
    [c2,c4,c5,c6].each {|c| c.links.should have_exactly(2).items}

    # check the links in each p and c
    p_link = JiakLink.new(@p_bucket,'k','parent')
    c_link = JiakLink.new(@c_bucket,'k','child')
    parent_children.each do |p_name,children|
      parent = @client.get(@p_bucket,p_name)
      links = parent.links
      children.each do |c_name|
        c_link.key = c_name
        parent.links.should include c_link

        child = @client.get(@c_bucket,c_name)
        p_link.key = p_name
        child.links.should include p_link
      end
    end
    
    # p's should include links to their c's
    c_link = QueryLink.new(@c_bucket,'child',nil)
    parent_children.each do |p_name,children|
      @client.walk(@p_bucket,p_name,c_link,PersonData).each do |c_obj|
        children.should include c_obj.data.name
      end
    end

    # c's should include links to their p's
    p_link = QueryLink.new(@p_bucket,'parent',nil)
    child_parents.each do |c_name,parents|
      @client.walk(@c_bucket,c_name,p_link,PersonData).each do |p_obj|
        parents.should include p_obj.data.name
      end
    end

    # c siblings requires a second step
    c1s,c2s,c3s,c4s,c5s,c6s,c7s = child_parents.keys.map do |c|
      siblings = @client.walk(@c_bucket,c,[p_link,c_link],PersonData)
      me = @client.get(@c_bucket,c)
      siblings.reject! {|s| s.eql?(me)}
      siblings
    end
    c1s.should have_exactly(1).item
    c2s.should have_exactly(3).items
    c3s.should have_exactly(2).items
    c4s.should have_exactly(4).items
    c5s.should have_exactly(2).items
    c6s.should have_exactly(2).items
    c7s.should have_exactly(0).items
  end

end
