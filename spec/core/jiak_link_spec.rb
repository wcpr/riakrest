require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakLink" do
  before do
    @bucket = 'b'
    @tag = 't'
    @acc = 'a'
    @any = JiakLink::ANY
    @jiak_link = JiakLink.create({:bucket => @bucket,:tag => @tag,:acc =>@acc})
    @array = [@bucket,@tag,@acc]
    @jiak_link_any = JiakLink.create
  end

  it "should respond to" do
    JiakLink.should respond_to(:create)
    JiakLink.should_not respond_to(:new)

    @jiak_link.should respond_to(:bucket,:tag,:acc)
    @jiak_link.should_not respond_to(:bucket=,:tag=,:acc=)

    @jiak_link.should respond_to(:for_jiak,:for_uri)

    @jiak_link.should respond_to(:eql?,:==)
  end

  it "should fill in missing opts with ANY" do
    jiak_link = JiakLink.create
    jiak_link.should eql @jiak_link_any
    jiak_link.should == @jiak_link_any

    [:bucket,:tag,:acc].each do |key|
      hash = {}
      hash[key] = @any
      jiak_link = JiakLink.create(hash)
      jiak_link.should eql @jiak_link_any
      jiak_link.should == @jiak_link_any
    end
  end

  it "should init from specified values" do
    @jiak_link.bucket.should eql @bucket
    @jiak_link.tag.should eql @tag
    @jiak_link.acc.should eql @acc

    jiak_link = JiakLink.create({:bucket => @bucket,:tag => @tag})
    jiak_link.bucket.should eql @bucket
    jiak_link.tag.should eql @tag
    jiak_link.acc.should eql @any

    jiak_link = JiakLink.create([@bucket,@tag,@acc])
    jiak_link.bucket.should eql @bucket
    jiak_link.tag.should eql @tag
    jiak_link.acc.should eql @acc
  end

  it "should ignore leading/trailing spaces for opts on init" do
    bucket = " "+@bucket+" "
    tag = " "+@tag+" "
    acc = " "+@acc+" "
    jiak_link = JiakLink.create([bucket,tag,acc])
    jiak_link.bucket.should eql @bucket
    jiak_link.tag.should eql @tag
    jiak_link.acc.should eql @acc
  end
  
  it "should treat blank, empty strings, or nil as ANY on init" do
    jiak_any_link = JiakLink.create

    ["","  ",nil].each do |val|
      jiak_link = JiakLink.create([val,val,val])
      jiak_link.should eql jiak_any_link
      jiak_link.should == jiak_any_link
    end
  end

  it "should init from an array" do
    jiak_link = JiakLink.create(@array)
    jiak_link.bucket.should eql @bucket
    jiak_link.tag.should eql @tag
    jiak_link.acc.should eql @acc
  end

  it "should convert for Jiak" do
    @jiak_link.for_jiak.should eql @array
  end
  
  it "should convert to a suitable URI string" do
    @jiak_link.for_uri.should eql @bucket+','+@tag+','+@acc

    b = 's p a c e'
    t = '<%>'
    a = '\\'
    jiak_link = JiakLink.create([b,t,a])
    jiak_link.for_uri.should eql URI.encode([b,t,a].join(','))
  end

  it "should compare to another JiakLink via eql?" do
    jiak_link_1 = JiakLink.create(['a','b','c'])
    jiak_link_2 = JiakLink.create(['a','b','c'])
    jiak_link_3 = JiakLink.create(['a','','c'])
    
    jiak_link_1.should eql jiak_link_2
    jiak_link_1.should_not eql jiak_link_3

    jiak_link_1.should == jiak_link_2
    jiak_link_1.should_not == jiak_link_3
  end
end
