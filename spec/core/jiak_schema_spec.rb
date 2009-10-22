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
    @jiak_schema = JiakSchema.create(@hash)
  end

  it "should respond to" do
    JiakSchema.should respond_to(:create,:from_jiak)

    @jiak_schema.should respond_to(:allowed_fields,:allowed_fields=)
    @jiak_schema.should respond_to(:required_fields,:required_fields=)
    @jiak_schema.should respond_to(:read_mask,:read_mask=)
    @jiak_schema.should respond_to(:write_mask,:write_mask=)

    @jiak_schema.should respond_to(:to_jiak)
    @jiak_schema.should respond_to(:eql?)
  end

  it "should create using defaults from allowed_fields" do
    jiak_schema = JiakSchema.create({:allowed_fields => @allowed_fields})
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql @allowed_fields
    jiak_schema.write_mask.should eql @allowed_fields

    jiak_schema = JiakSchema.create(@allowed_fields)
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql @allowed_fields
    jiak_schema.write_mask.should eql @allowed_fields

    jiak_schema = JiakSchema.create({:allowed_fields => []})
    jiak_schema.allowed_fields.should eql []
    jiak_schema.required_fields.should eql []
    jiak_schema.read_mask.should eql []
    jiak_schema.write_mask.should eql []

    jiak_schema = JiakSchema.create([])
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
    jiak_schema = JiakSchema.create(@hash)
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql @required_fields
    jiak_schema.read_mask.should eql @read_mask
    jiak_schema.write_mask.should eql @write_mask

    hash = {:schema => @hash}
    jiak_schema = JiakSchema.create(hash)
    jiak_schema.should eql @jiak_schema

    @hash['allowed_fields'] = @hash[:allowed_fields]
    @hash.delete(:allowed_fields)
    @hash['read_mask'] = @hash[:read_mask]
    @hash.delete(:read_mask)
    jiak_schema = JiakSchema.create(@hash)
    jiak_schema.allowed_fields.should eql @allowed_fields
    jiak_schema.required_fields.should eql @required_fields
    jiak_schema.read_mask.should eql @read_mask
    jiak_schema.write_mask.should eql @write_mask
  end

  it "should create from json" do
    schema = JiakSchema.from_jiak(@hash.to_json)
    @allowed_fields.same_fields?(schema.allowed_fields).should be true
    @required_fields.same_fields?(schema.required_fields).should be true
    @write_mask.same_fields?(schema.write_mask).should be true
    @read_mask.same_fields?(schema.read_mask).should be true
  end

  it "should validate create options" do
    hash = @hash.clone
    hash.delete(:allowed_fields)
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    hash = @hash.clone
    hash[:allowed_fields] = nil
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    hash[:allowed_fields] = 'a'
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    hash = @hash.clone
    hash[:required_fields] = {}
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/required_fields.*array/)

    hash = @hash.clone
    hash[:read_mask] = [1]
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/read_mask.*strings/)

    hash = @hash.clone
    hash[:write_mask] = ['a','b',3]
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/write_mask.*strings/)

    hash = @hash.clone
    hash[:allowed_fields] << @allowed_fields[0].to_s
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/unique/)

    hash = @hash.clone
    hash[:allowed_fields] << @allowed_fields[0].to_sym
    bad = lambda {JiakSchema.create(hash)}
    bad.should raise_error(JiakSchemaException,/unique/)
  end

  it "should update with validation" do
    arr = [:f1,'f2']
    @jiak_schema.allowed_fields = arr
    @jiak_schema.allowed_fields.should eql arr
    @jiak_schema.required_fields = arr
    @jiak_schema.required_fields.should eql arr
    @jiak_schema.read_mask = arr
    @jiak_schema.read_mask.should eql arr
    @jiak_schema.write_mask = arr
    @jiak_schema.write_mask.should eql arr

    bad = lambda {@jiak_schema.allowed_fields = nil}
    bad.should raise_error(JiakSchemaException,/allowed_fields.*array/)

    bad = lambda {@jiak_schema.required_fields = 'a'}
    bad.should raise_error(JiakSchemaException,/required_fields.*array/)

    bad = lambda {@jiak_schema.read_mask = [:f,1]}
    bad.should raise_error(JiakSchemaException,/read_mask.*symbol/)
    
    arr << :f1
    bad = lambda {@jiak_schema.write_mask = arr}
    bad.should raise_error(JiakSchemaException,/unique/)
  end

  it "should convert to json" do
    @jiak_schema.to_jiak.should eql ({:schema => @hash}.to_json)
  end

  it "should equal an equal JiakSchema" do
    jiak_schema = JiakSchema.create(@hash)
    jiak_schema.should eql @jiak_schema

    strings = JiakSchema.create(['a','bb','CcC'])
    symbols = JiakSchema.create([:a,:bb,:CcC])
    strings.should eql symbols
    symbols.should eql strings

    strings = JiakSchema.create(['a','bb','CcC','d'])
    symbols = JiakSchema.create([:a,:bb,:CcC])
    strings.should_not eql symbols
    symbols.should_not eql strings

    strings = JiakSchema.create(['a','bb','CC'])
    symbols = JiakSchema.create([:a,:bb,:CcC])
    strings.should_not eql symbols
    symbols.should_not eql strings
  end

end
