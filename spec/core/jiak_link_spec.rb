require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakLink" do
  before do
    @bucket = 'b'
    @key = 'k'
    @tag = 't'
    @jiak_link = JiakLink.new(@bucket,@key,@tag)
  end

  it "should respond to" do
    @jiak_link.should respond_to(:bucket,:key,:tag)
    @jiak_link.should respond_to(:bucket=,:key=,:tag=)

    @jiak_link.should respond_to(:for_jiak)

    @jiak_link.should respond_to(:eql?,:==)
  end

  it "should init from specified values" do
    @jiak_link.bucket.should eql @bucket
    @jiak_link.key.should eql @key
    @jiak_link.tag.should eql @tag

    jiak_link = JiakLink.new(@jiak_link)
    jiak_link.bucket.should eql @bucket
    jiak_link.key.should eql @key
    jiak_link.tag.should eql @tag

    jiak_link = JiakLink.new(['b','k','t'])
    jiak_link.bucket.should eql 'b'
    jiak_link.key.should eql 'k'
    jiak_link.tag.should eql 't'
  end

  it "should ignore leading/trailing spaces for opts on init" do
    bucket = " "+@bucket+" "
    key = " "+@key+" "
    tag = " "+@tag+" "
    jiak_link = JiakLink.new(bucket,key,tag)
    jiak_link.bucket.should eql @bucket
    jiak_link.key.should eql @key
    jiak_link.tag.should eql @tag
  end
  
  it "should reject blank, empty strings, or nil values on init" do
    ["","  ",nil].each do |bucket|
      bad_bucket = lambda { JiakLink.new(bucket,'k','t') }
      bad_bucket.should raise_error(JiakLinkException)
    end
  end

  it "should allow field updates" do
    @jiak_link.bucket = 'new_bucket'
    @jiak_link.bucket.should eql 'new_bucket'
    @jiak_link.key = 'new_key'
    @jiak_link.key.should eql 'new_key'
    @jiak_link.tag = 'new_tag'
    @jiak_link.tag.should eql 'new_tag'
  end

  it "should convert for Jiak" do
    @jiak_link.for_jiak.should eql [@bucket,@key,@tag]
  end
  
  it "should compare to another JiakLink via eql?" do
    jiak_link_1 = JiakLink.new('a','b','c')
    jiak_link_2 = JiakLink.new('a','b','c')
    jiak_link_3 = JiakLink.new('a','~b','c')
    
    jiak_link_1.should eql jiak_link_2
    jiak_link_1.should_not eql jiak_link_3

    jiak_link_1.should == jiak_link_2
    jiak_link_1.should_not == jiak_link_3
  end
end
