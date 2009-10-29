require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakResource" do
  F1F2 = JiakDataHash.create(:f1,:f2)
  class Rsrc
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'group'
    data_class   F1F2
  end

  before do
    @server = 'http://localhost:8002/jiak'
    @group = 'group'
    @data_class = F1F2
  end

  describe "class" do
    it "should respond to" do
      Rsrc.should respond_to(:server,:group,:data_class)
      Rsrc.should respond_to(:params,:auto_update,:schema,:keys)
      Rsrc.should respond_to(:allowed,:required,:readable,:writable,:readwrite)
      Rsrc.should respond_to(:point_of_view,:pov,:point_of_view?,:pov?)
      Rsrc.should respond_to(:post,:put,:get,:delete)
      Rsrc.should respond_to(:refresh,:update)
      Rsrc.should respond_to(:link,:bi_link,:walk)
      Rsrc.should respond_to(:new,:copy)
      Rsrc.should respond_to(:auto_post,:auto_update,:auto_post?,:auto_update?)

      Rsrc.jiak.should respond_to(:server,:uri,:group,:data,:bucket,:auto_update)
                                  
                                  
    end
    
    it "shoud have settings from creation" do
      Rsrc.params.should be_empty
      Rsrc.auto_update?.should be false
      Rsrc.schema.should eql F1F2.schema
      
      Rsrc.jiak.should be_a Struct
      Rsrc.jiak.server.should be_a JiakClient
      Rsrc.jiak.uri.should eql @server
      Rsrc.jiak.group.should eql @group
      Rsrc.jiak.data.should include JiakData
      Rsrc.jiak.data.should == F1F2
      Rsrc.jiak.bucket.should be_a JiakBucket
      Rsrc.jiak.bucket.name.should eql @group
      Rsrc.jiak.bucket.data_class.should == F1F2
      Rsrc.jiak.auto_update.should be false
    end
  end

  describe "instance" do
    before do
      @rsrc = Rsrc.new
    end

    it "should respond to" do
      @rsrc.should respond_to(:jiak,:jiak=)
      @rsrc.should respond_to(:auto_update=,:auto_update?)
      @rsrc.should respond_to(:post,:put,:update,:refresh,:delete)
      @rsrc.should respond_to(:link,:bi_link,:walk)
      @rsrc.should respond_to(:eql?,:==)
    end
    
    it "should have default settings" do
      @rsrc.jiak.should be_a Struct
      @rsrc.jiak.should respond_to(:obj,:auto_update)
      
      @rsrc.jiak.obj.should be_a JiakObject
      @rsrc.jiak.obj.bucket.should be_a JiakBucket
      @rsrc.jiak.obj.bucket.name.should eql @group
      @rsrc.jiak.obj.bucket.data_class.should == F1F2
      
      @rsrc.jiak.auto_update.should be_nil
    end
  end
end

describe "JiakResource default class-level auto-post" do
  PersonData = JiakDataHash.create(:name,:age)
  PersonData.keygen :name
  class Person
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'people'
    data_class   PersonData
  end

  it "should create instance without posting" do
    Person.auto_post?.should be false

    name = 'p'
    p = Person.new(:name => name, :age => 10)

    no_rsrc = lambda {Person.get(name)}
    no_rsrc.should raise_error(JiakResourceNotFound)

    p.post
    Person.get(name).name.should eql p.name

    p.delete
  end
end

describe "JiakResource class-level auto-post true" do
  PersonData = JiakDataHash.create(:name,:age)
  PersonData.keygen :name
  class Person
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'people'
    data_class   PersonData
    auto_post    true
  end

  it "should auto-post a new instance" do
    Person.auto_post?.should be true
    
    name = 'P'
    p = Person.new(:name => name, :age => 10)
    Person.get(name).name.should eql name
    p.delete
  end
end


# CxINC Many, many more tests to go
