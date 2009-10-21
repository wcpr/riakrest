require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "Jiak exceptions" do
  it "should all be a kind of RiakRest::Exception" do
    JiakResourceException.new.should be_a_kind_of RiakRest::Exception
    JiakResourceNotFound.new.should be_a_kind_of RiakRest::Exception
    JiakClientException.new.should be_a_kind_of RiakRest::Exception
    JiakObjectException.new.should be_a_kind_of RiakRest::Exception
    JiakSchemaException.new.should be_a_kind_of RiakRest::Exception
    JiakLinkException.new.should be_a_kind_of RiakRest::Exception
  end
end

describe "JiakResource hierarchy" do
  it "should have resource not found" do
    JiakResourceNotFound.new.should be_a_kind_of JiakResourceException
  end
end
