require File.dirname(__FILE__) + '/../spec_helper.rb'

class FooBarBaz  # :nodoc:
  include JiakData

  allowed  :foo, :bar, :baz
  required :foo
  readable :foo, :bar
  writable :foo, :bar

  def initialize(hsh)
    hsh.each {|key,val| send("#{key}=",val)}
  end

  def self.jiak_create(jiak)
    new(jiak)
  end

  def for_jiak
    { :foo => @foo,
      :bar => @bar
    }.reject {|k,v| v.nil?}
  end

  def eql?(other)
    other.is_a?(FooBarBaz) && other.foo.eql?(@foo) && other.bar.eql?(@bar)
  end
end

describe "JiakClient init" do
  before do
    @base_uri = 'http://127.0.0.1:8002/jiak/'
    @client = JiakClient.new @base_uri
  end

  it "should respond to" do
    @client.should respond_to(:set_schema, :schema, :keys)
    @client.should respond_to(:uri)
    @client.should respond_to(:get, :store, :delete, :walk)
  end

  it "should default to base URI" do
    @client.uri.should match @base_uri
  end

  it "should allow specified base URI" do
    base_uri = 'http://localhost:1234/tmp/'
    client = JiakClient.new base_uri
    client.uri.should match base_uri
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
      FooBarBazBuz = JiakDataHash.create(:foo,:bar,:baz,:buz)
      @client.set_schema(JiakBucket.new(@bucket_name,FooBarBazBuz))
      
      resp_schema = @client.schema(@bucket)
      resp_schema.allowed_fields.should include 'buz'
      resp_schema.required_fields.should be_empty
      resp_schema.read_mask.should include 'baz'
      resp_schema.write_mask.should include 'baz'

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
        resp = @client.store(jobj,{:object => true})
        resp.should be_a JiakObject
        resp.bucket.should eql @bucket
        resp.key.should eql key
        resp.data.should be_a FooBarBaz

        jobj = JiakObject.new(:bucket => @bucket, :data => @data)
        resp = @client.store(jobj,{:object => true})
        resp.should be_a JiakObject
        resp.key.should_not be_nil
        resp.data.should be_a FooBarBaz
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
                        {:object => true})
        
        jobj.data.should eql @data
        [:vclock,:vtag,:lastmod].each do |field|
          jobj.riak.should include field
          jobj.riak[field].should be_a String
          jobj.riak[field].should_not be_empty
        end

        updated_data = FooBarBaz.new(:foo => 'new val')
        jobj.data = updated_data
        updated_object = 
          @client.store(jobj,{:object => true})
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

Parent = JiakDataHash.create(:name)
Child = JiakDataHash.create(:name,:parent)

describe "JiakClient links" do
  before do
    @base_uri = 'http://127.0.0.1:8002/jiak/'
    @client = JiakClient.new @base_uri

    @parent_bucket = JiakBucket.new('parents',Parent)
    @children_bucket = JiakBucket.new('children',Child)
    @client.set_schema(@parent_bucket)
    @client.set_schema(@children_bucket)
  end

  it "should add links and walk the resulting structure" do
    parent_keys = ['parent_1','parent_2','parent_3','parent_4']
    parent_keys.each do |parent_key|
      parent_name = parent_key.gsub('_',' ')
      parent_data = Parent.new(:name => parent_name)
      jobj = JiakObject.new(:bucket => @parent_bucket,
                            :key => parent_key,
                            :data => parent_data)
      @client.store(jobj)
    end
    parent_children = {
      'parent_1' => ['child_1','child_2'],
      'parent_2' => ['child_2','child_3'],
      'parent_3' => ['child_4','child_5','child_6'],
      'parent_4' => ['child_4','child_5','child_6']
    }
    
    parent_children.each do |parent_key,children_keys|
      children_keys.each do |child_key|
        child_name = child_key.gsub('_',' ')
        child_data = Child.new(:name => child_name, :parent => parent_key)
        child_jobj = 
          JiakObject.new(:bucket => @children_bucket,
                         :key => child_key,
                         :data => child_data)
        @client.store(child_jobj)
        child_link =
          JiakLink.new([@children_bucket.name,child_jobj.key,'child'])
        parent_jobj = @client.get(@parent_bucket,parent_key)
        parent_jobj << child_link
        @client.store(parent_jobj)
      end
    end

    parent_children.each do |parent_key,children_keys|
      parent = @client.get(@parent_bucket,parent_key)
      children_keys.each do |child_key|
        child_link = JiakLink.new([@children_bucket.name,child_key,'child'])
        parent.links.should include child_link
      end
    end
    
    walker = JiakLink.new([@children_bucket.name,JiakLink::ANY,'child'])
    parent_keys.each do |parent_key|
      @client.walk(@parent_bucket,parent_key,walker).each do |child|
        child_data = child['object']
        child_name = child_data['name']
        child_key = child_name.gsub(' ','_')
        parent_children[parent_key].should include child_key
      end
    end
  end

  it "should walk a nested structure" do
    # CxINC Walk more than one step
  end
end
