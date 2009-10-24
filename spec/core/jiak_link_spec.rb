require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakLink" do
  before do
    @bucket = 'b'
    @key = 'k'
    @tag = 't'
    @any = JiakLink::ANY
    @jiak_link = JiakLink.new({:bucket => @bucket,:key => @key,:tag =>@tag})
    @array = [@bucket,@key,@tag]
    @jiak_link_any = JiakLink.new
  end

  it "should respond to" do
    @jiak_link.should respond_to(:bucket,:key,:tag)
    @jiak_link.should_not respond_to(:bucket=,:key=,:tag=)

    @jiak_link.should respond_to(:for_jiak,:for_uri)

    @jiak_link.should respond_to(:eql?,:==)
  end

  it "should fill in missing opts with ANY" do
    jiak_link = JiakLink.new
    jiak_link.should eql @jiak_link_any
    jiak_link.should == @jiak_link_any

    [:bucket,:key,:tag].each do |key|
      hash = {}
      hash[key] = @any
      jiak_link = JiakLink.new(hash)
      jiak_link.should eql @jiak_link_any
      jiak_link.should == @jiak_link_any
    end
  end

  it "should init from specified values" do
    @jiak_link.bucket.should eql @bucket
    @jiak_link.key.should eql @key
    @jiak_link.tag.should eql @tag

    jiak_link = JiakLink.new({:bucket => @bucket,:key => @key})
    jiak_link.bucket.should eql @bucket
    jiak_link.key.should eql @key
    jiak_link.tag.should eql @any

    jiak_link = JiakLink.new([@bucket,@key,@tag])
    jiak_link.bucket.should eql @bucket
    jiak_link.key.should eql @key
    jiak_link.tag.should eql @tag
  end

  it "should ignore leading/trailing spaces for opts on init" do
    bucket = " "+@bucket+" "
    key = " "+@key+" "
    tag = " "+@tag+" "
    jiak_link = JiakLink.new([bucket,key,tag])
    jiak_link.bucket.should eql @bucket
    jiak_link.key.should eql @key
    jiak_link.tag.should eql @tag
  end
  
  it "should treat blank, empty strings, or nil as ANY on init" do
    jiak_any_link = JiakLink.new

    ["","  ",nil].each do |val|
      jiak_link = JiakLink.new([val,val,val])
      jiak_link.should eql jiak_any_link
      jiak_link.should == jiak_any_link
    end
  end

  it "should init from an array" do
    jiak_link = JiakLink.new(@array)
    jiak_link.bucket.should eql @bucket
    jiak_link.key.should eql @key
    jiak_link.tag.should eql @tag
  end

  it "should convert for Jiak" do
    @jiak_link.for_jiak.should eql @array
  end
  
  it "should convert to a suitable URI string" do
    @jiak_link.for_uri.should eql @bucket+','+@key+','+@tag

    b = 's p a c e'
    t = '<%>'
    a = '\\'
    jiak_link = JiakLink.new([b,t,a])
    jiak_link.for_uri.should eql URI.encode([b,t,a].join(','))
  end

  it "should compare to another JiakLink via eql?" do
    jiak_link_1 = JiakLink.new(['a','b','c'])
    jiak_link_2 = JiakLink.new(['a','b','c'])
    jiak_link_3 = JiakLink.new(['a','','c'])
    
    jiak_link_1.should eql jiak_link_2
    jiak_link_1.should_not eql jiak_link_3

    jiak_link_1.should == jiak_link_2
    jiak_link_1.should_not == jiak_link_3
  end
end
