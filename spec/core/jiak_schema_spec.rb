require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakSchema" do
  before do
    @allowed_fields = [:foo,:bar,:baz]
    @required_fields = [:foo]
    @read_mask = [:foo,:bar]
    @write_mask = [:baz]
    @hash = {
      :allowed_fields => @allowed_fields,
      :required_fields => @required_fields,
      :read_mask => @read_mask,
      :write_mask => @write_mask
    }
    @jiak_schema = JiakSchema.new(@hash)
  end

  it "should respond to" do
    JiakSchema.should respond_to(:jiak_create)

    @jiak_schema.should respond_to(:allowed_fields,:allowed_fields=)
    @jiak_schema.should respond_to(:required_fields,:required_fields=)
    @jiak_schema.should respond_to(:read_mask,:read_mask=)
    @jiak_schema.should respond_to(:write_mask,:write_mask=)
    @jiak_schema.should respond_to(:allow,:require,:readable,:writable)

    @jiak_schema.should respond_to(:to_jiak)
    @jiak_schema.should respond_to(:==,:eql?)
  end

  it "should create using defaults from allowed_fields" do
    jiak_schema = JiakSchema.new({:allowed_fields => @allowed_fields})
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql @allowed_fields
    jiak_schema.write_mask.should eql @allowed_fields

    jiak_schema = JiakSchema.new(@allowed_fields)
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql @allowed_fields
    jiak_schema.write_mask.should eql @allowed_fields

    jiak_schema = JiakSchema.new({:allowed_fields => []})
    jiak_schema.allowed_fields.should eql []
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql []
    jiak_schema.write_mask.should eql []

    jiak_schema = JiakSchema.new([])
    jiak_schema.allowed_fields.should eql []
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql []
    jiak_schema.write_mask.should eql []
  end

  it "should create using specified fields and masks" do
    @jiak_schema.allowed_fields.should eql @allowed_fields
    @jiak_schema.required_fields.should eql @required_fields
    @jiak_schema.read_mask.should eql @read_mask
    @jiak_schema.write_mask.should eql @write_mask
  end

  it "should create from a Hash" do
    jiak_schema = JiakSchema.new(@hash)
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql @required_fields
    jiak_schema.read_mask.should eql @read_mask
    jiak_schema.write_mask.should eql @write_mask

    hash = {:schema => @hash}
    jiak_schema = JiakSchema.new(hash)
    jiak_schema.should eql @jiak_schema
    jiak_schema.should ==  @jiak_schema

    @hash['allowed_fields'] = @hash[:allowed_fields]
    @hash.delete(:allowed_fields)
    @hash['read_mask'] = @hash[:read_mask]
    @hash.delete(:read_mask)
    jiak_schema = JiakSchema.new(@hash)
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql @required_fields
    jiak_schema.read_mask.should eql @read_mask
    jiak_schema.write_mask.should eql @write_mask
  end

  it "should create an empty schema" do
    [JiakSchema.new, JiakSchema.new {}].each do |schema|
      schema.allowed_fields.should be_empty
      schema.required_fields.should be_empty
      schema.read_mask.should be_empty
      schema.write_mask.should be_empty
    end
  end

  it "should create from json" do
    schema = JiakSchema.jiak_create(JSON.parse(@hash.to_json))
    @allowed_fields.same_fields?(schema.allowed_fields).should be true
    @required_fields.same_fields?(schema.required_fields).should be true
    @write_mask.same_fields?(schema.write_mask).should be true
    @read_mask.same_fields?(schema.read_mask).should be true
  end

  it "should validate create options" do
    hash = @hash.clone
    hash.delete(:allowed_fields)
    bad = lambda {JiakSchema.new(hash)}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    hash = @hash.clone
    hash[:allowed_fields] = nil
    bad = lambda {JiakSchema.new(hash)}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    hash[:allowed_fields] = 'a'
    bad = lambda {JiakSchema.new(hash)}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    hash = @hash.clone
    hash[:required_fields] = {}
    bad = lambda {JiakSchema.new(hash)}
    bad.should raise_error(JiakSchemaException,/required_fields.*array/)

    hash = @hash.clone
    hash[:read_mask] = [1]
    bad = lambda {JiakSchema.new(hash)}
    bad.should raise_error(JiakSchemaException,/read_mask.*strings/)

    hash = @hash.clone
    hash[:write_mask] = ['a','b',3]
    bad = lambda {JiakSchema.new(hash)}
    bad.should raise_error(JiakSchemaException,/write_mask.*strings/)

  end
  
  it "should ignore duplicate fields" do
    hash = @hash.clone
    hash[:allowed_fields] << @allowed_fields[0].to_s
    jiak_schema = JiakSchema.new(hash)
    jiak_schema.should eql @jiak_schema

    jiak_schema.allowed_fields = hash[:allowed_fields]
    jiak_schema.allowed_fields.should eql @jiak_schema.allowed_fields

    hash[:read_mask] << @read_mask[0]
    jiak_schema.read_mask = hash[:read_mask]
    jiak_schema.read_mask.should eql @hash[:read_mask]

    hash[:write_mask] << @write_mask[0]
    jiak_schema.write_mask = hash[:write_mask]
    jiak_schema.write_mask.should eql @hash[:write_mask]

    jiak_schema.readwrite = hash[:read_mask]
    jiak_schema.read_mask.should eql @hash[:read_mask]
    jiak_schema.write_mask.should eql @hash[:read_mask]
  end

  it "should update individual arrays" do
    arr1    = [:f1]
    arr12   = [:f1,:f2]
    arr13   = [:f1,:f3]
    arr14   = [:f1,:f4]
    arr123  = [:f1,:f2,:f3]
    arr1234 = [:f1,:f2,:f3,:f4]

    jiak_schema = JiakSchema.new(arr1)
    jiak_schema.allow :f2
    jiak_schema.allowed_fields.should eql arr12
    jiak_schema.read_mask.should eql arr1
    jiak_schema.write_mask.should eql arr1
    jiak_schema.required_fields.should be_empty
    jiak_schema.readable :f3
    jiak_schema.read_mask.should eql arr13
    jiak_schema.write_mask.should eql arr1
    jiak_schema.allowed_fields.should eql arr123
    jiak_schema.required_fields.should be_empty
    jiak_schema.writable :f4
    jiak_schema.write_mask.should eql arr14
    jiak_schema.read_mask.should eql arr13
    jiak_schema.allowed_fields.should eql arr1234
    jiak_schema.required_fields.should be_empty

    jiak_schema = JiakSchema.new(arr1)
    jiak_schema.readwrite :f2
    jiak_schema.read_mask.should eql arr12
    jiak_schema.write_mask.should eql arr12
    jiak_schema.allowed_fields.should eql arr12
    jiak_schema.required_fields.should be_empty

    jiak_schema.require :f3
    jiak_schema.required_fields.should eql [:f3]
    jiak_schema.allowed_fields.should eql arr123
    jiak_schema.read_mask.should eql arr123
    jiak_schema.write_mask.should eql arr123
  end

  it "should return added fields when updating individual arrays" do
    arr12 = [:f1,:f2]
    arr23 = [:f2,:f3]
    jiak_schema = JiakSchema.new
    added = jiak_schema.allow arr12
    added.should eql arr12
    added = jiak_schema.allow arr23
    added.should eql [:f3]

    # other add methods call same internal method. previous test checks this is
    # true so don't need more tests here
  end

  it "should set arrays with validation" do
    arr = [:f1,'f2']
    @jiak_schema.allowed_fields = arr
    @jiak_schema.allowed_fields.should_not eql arr
    @jiak_schema.allowed_fields.same_fields?(arr).should eql true
    @jiak_schema.required_fields = arr
    @jiak_schema.required_fields.should_not eql arr
    @jiak_schema.required_fields.same_fields?(arr).should eql true
    @jiak_schema.read_mask = arr
    @jiak_schema.read_mask.should_not eql arr
    @jiak_schema.read_mask.same_fields?(arr).should eql true
    @jiak_schema.write_mask = arr
    @jiak_schema.write_mask.should_not eql arr
    @jiak_schema.write_mask.same_fields?(arr).should eql true

    bad = lambda {@jiak_schema.allowed_fields = nil}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    bad = lambda {@jiak_schema.required_fields = 'a'}
    bad.should raise_error(JiakSchemaException,/required_fields.*array/)

    bad = lambda {@jiak_schema.read_mask = [:f,1]}
    bad.should raise_error(JiakSchemaException,/read_mask.*symbol/)
  end

  it "should ignore duplicates on setting of arrays" do
    arr    = [:f1,:f2,:f1,:f3]
    arr123 = [:f1,:f2,:f3]

    @jiak_schema.allowed_fields = arr
    @jiak_schema.allowed_fields.should eql arr123

    @jiak_schema.required_fields = arr
    @jiak_schema.required_fields.should eql arr123

    @jiak_schema.read_mask = arr
    @jiak_schema.read_mask.should eql arr123

    @jiak_schema.write_mask = arr
    @jiak_schema.write_mask.should eql arr123

    @jiak_schema.allow :f1
    @jiak_schema.allowed_fields.should eql arr123

    @jiak_schema.readable :f2
    @jiak_schema.read_mask.should eql arr123

    @jiak_schema.writable :f3
    @jiak_schema.read_mask.should eql arr123

    @jiak_schema.require :f2
    @jiak_schema.required_fields.should eql arr123
  end

  it "should convert to json" do
    @jiak_schema.to_jiak.should eql({:schema => @hash})
  end

  it "should equal an equal JiakSchema" do
    jiak_schema = JiakSchema.new(@hash)
    jiak_schema.should eql @jiak_schema

    strings = JiakSchema.new(['a','bb','CcC'])
    symbols = JiakSchema.new([:a,:bb,:CcC])
    strings.should eql symbols
    symbols.should eql strings

    strings = JiakSchema.new(['a','bb','CcC','d'])
    symbols = JiakSchema.new([:a,:bb,:CcC])
    strings.should_not eql symbols
    symbols.should_not eql strings

    strings = JiakSchema.new(['a','bb','CC'])
    symbols = JiakSchema.new([:a,:bb,:CcC])
    strings.should_not eql symbols
    symbols.should_not eql strings
  end

end
