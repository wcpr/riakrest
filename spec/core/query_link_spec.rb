require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "QueryLink" do
  before do
    @bucket = 'b'
    @tag = 't'
    @acc = 'a'
    @any = QueryLink::ANY
    @query_link = QueryLink.new(@bucket,@tag,@acc)
    @array = [@bucket,@tag,@acc]
    @query_link_any = QueryLink.new
  end

  it "should respond to" do
    @query_link.should respond_to(:bucket,:tag,:acc)
    @query_link.should respond_to(:bucket=,:tag=,:acc=)

    @query_link.should respond_to(:for_uri)

    @query_link.should respond_to(:eql?,:==)
  end

  it "should init from specified values" do
    @query_link.bucket.should eql @bucket
    @query_link.tag.should eql @tag
    @query_link.acc.should eql @acc

    query_link = QueryLink.new([@bucket,@tag,@acc])
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @tag
    query_link.acc.should eql @acc

    query_link = QueryLink.new(@query_link)
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @tag
    query_link.acc.should eql @acc
  end

  it "should fill in missing args with ANY" do
    query_link = QueryLink.new(@bucket,@tag)
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @tag
    query_link.acc.should eql @any

    query_link = QueryLink.new(@bucket)
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @any
    query_link.acc.should eql @any

    query_link = QueryLink.new
    query_link.bucket.should eql @any
    query_link.tag.should eql @any
    query_link.acc.should eql @any

    query_link = QueryLink.new([@bucket,@tag])
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @tag
    query_link.acc.should eql @any
    
    query_link = QueryLink.new([@bucket])
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @any
    query_link.acc.should eql @any

    query_link = QueryLink.new []
    query_link.bucket.should eql @any
    query_link.tag.should eql @any
    query_link.acc.should eql @any
  end

  it "should ignore leading/trailing spaces for opts on init" do
    bucket = " "+@bucket+" "
    tag = " "+@tag+" "
    acc = " "+@acc+" "
    query_link = QueryLink.new([bucket,tag,acc])
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @tag
    query_link.acc.should eql @acc
  end
  
  it "should treat blank, empty strings, or nil as ANY on init" do
    jiak_any_link = QueryLink.new

    ["","  ",nil].each do |val|
      query_link = QueryLink.new([val,val,val])
      query_link.should eql jiak_any_link
      query_link.should == jiak_any_link
    end
  end

  it "should init from an array" do
    query_link = QueryLink.new(@array)
    query_link.bucket.should eql @bucket
    query_link.tag.should eql @tag
    query_link.acc.should eql @acc
  end

  it "should allow field updates" do
    @query_link.bucket = 'new_bucket'
    @query_link.bucket.should eql 'new_bucket'
    @query_link.tag = 'new_tag'
    @query_link.tag.should eql 'new_tag'
    @query_link.acc = 'new_acc'
    @query_link.acc.should eql 'new_acc'
  end

  it "should convert to a suitable URI string" do
    @query_link.for_uri.should eql @bucket+','+@tag+','+@acc

    b = 's p a c e'
    t = '<%>'
    a = '\\'
    query_link = QueryLink.new([b,t,a])
    query_link.for_uri.should eql URI.encode([b,t,a].join(','))
  end

  it "should compare to another QueryLink via eql?" do
    query_link_1 = QueryLink.new(['a','b','c'])
    query_link_2 = QueryLink.new(['a','b','c'])
    query_link_3 = QueryLink.new(['a','','c'])
    
    query_link_1.should eql query_link_2
    query_link_1.should_not eql query_link_3

    query_link_1.should == query_link_2
    query_link_1.should_not == query_link_3
  end
end
