require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakDataHash" do
  Person = JiakDataHash.create(:name, :age)

  before do
  end

  it "should create a fully usable JiakData class" do
    Person.schema.should respond_to(:allowed_fields,:required_fields,
                                    :read_mask,:write_mask)
  end

end
