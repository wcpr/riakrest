require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakResource default" do
  F1F2 = JiakDataHash.create(:f1,:f2)
  class Rsrc
    include JiakResource
    server       'http://localhost:8002/jiak/'
    group        'group'
    data_class   F1F2
  end

  before do
    @server = 'http://localhost:8002/jiak/'
    @group = 'group'
    @data_class = F1F2
  end

  describe "class creation" do
    it "should respond to" do
      Rsrc.should respond_to(:server,:group,:data_class)
      Rsrc.should respond_to(:params,:auto_update,:schema,:keys)
      Rsrc.should respond_to(:allowed,:required,:readable,:writable,:readwrite)
      Rsrc.should respond_to(:point_of_view,:pov,:point_of_view?,:pov?)
      Rsrc.should respond_to(:post,:put,:get,:delete)
      Rsrc.should respond_to(:refresh,:update,:exist?)
      Rsrc.should respond_to(:link,:bi_link,:walk)
      Rsrc.should respond_to(:new,:copy)
      Rsrc.should respond_to(:auto_post,:auto_update,:auto_post?,:auto_update?)

      Rsrc.jiak.should respond_to(:server,:uri,:group,:data,:bucket,:auto_update)
    end
    
    it "should have specified settings" do
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

    it "should copy with defaults and overrides" do
      Rsrc_default = Rsrc.copy
      Rsrc_default.jiak.uri.should eql @server
      Rsrc_default.jiak.group.should eql @group
      Rsrc_default.jiak.data.should == F1F2
      Rsrc_default.auto_post?.should == Rsrc.auto_post?
      Rsrc_default.auto_update?.should == Rsrc.auto_update?

      DiffData = JiakDataHash.create
      Rsrc_diff = Rsrc.copy(:server => 'scopy', :group => 'gcopy',
                            :data_class => DiffData,
                            :auto_post => true, :auto_update => true)
      Rsrc_diff.jiak.uri.should eql 'scopy'
      Rsrc_diff.jiak.group.should eql 'gcopy'
      Rsrc_diff.jiak.data.should == DiffData
      Rsrc_diff.auto_post?.should be true
      Rsrc_diff.auto_update?.should be true
    end
  end

  describe "instance creation" do
    before do
      @rsrc = Rsrc.new
    end

    it "should respond to" do
      @rsrc.should respond_to(:jiak,:jiak=)
      @rsrc.should respond_to(:auto_update=,:auto_update?)
      @rsrc.should respond_to(:post,:put,:delete)
      @rsrc.should respond_to(:update,:push,:refresh,:pull)
      @rsrc.should respond_to(:local?)
      @rsrc.should respond_to(:link,:bi_link,:walk)
      @rsrc.should respond_to(:eql?,:==)

      @rsrc.should respond_to(:f1,:f2)
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

describe "JiakResource default class-level auto-post/auto-update" do
  PersonData = JiakDataHash.create(:name,:age)
  PersonData.keygen :name
  class Person
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'people'
    data_class   PersonData
  end

  before do
    @name = 'p default'
    @p = Person.new(:name => @name, :age => 10)
  end

  it "should create instance without posting" do
    Person.auto_post?.should be false
    
    Person.exist?(@name).should be false
    @p.local?.should be true
    @p.post
    Person.get(@name).name.should eql @name
    @p.local?.should be false
    @p.delete
  end

  it "should change local data without updating" do
    @p.post
    Person.get(@name).age.should eql 10
    @p.age = 12
    Person.get(@name).age.should eql 10
    @p.update
    Person.get(@name).age.should eql 12
    @p.delete
  end

  it "should check if resource is local and if it exists on server" do
    name = 'p local'
    p = Person.new(:name => name)
    p.local?.should be true
    Person.exist?(name).should be false

    p.post
    p.local?.should be false
    Person.exist?(name).should be true

    p.delete
  end
end

describe "JiakResource class auto-post" do
  PersonData = JiakDataHash.create(:name,:age)
  PersonData.keygen :name
  class Person
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'people'
    data_class   PersonData
  end

  before do
    @name = 'p auto-post'
  end

  describe "false" do
    before do
      Person.auto_post false
    end

    it "should not auto-post, or auto-update a local object" do
      Person.auto_post?.should be false

      Person.exist?(@name).should be false

      Person.auto_update true
      p = Person.new(:name => @name, :age => 10)
      p.local?.should be true
      p.age = 12
      p.local?.should be true

      q = Person.new(:name => 'q', :age => 20)

      link_to_local = lambda {p.link(q,'link')}
      link_to_local.should raise_error(JiakResourceException,/local/)
      q.post

      q.local?.should be false

      p.link(q,'link')
      p.local?.should be true
      p.jiak.obj.links.size.should be 1

      p.post
      p.local?.should be false
      p.age.should be 12
      Person.get(@name).age.should be 12
      p.walk(Person,'link')[0].should eql q
      
      p.age = 10
      Person.get(@name).age.should be 10

      p.delete
      q.delete
    end
  end

  describe "true" do
    before do
      Person.auto_post true
    end

    it "should auto-post a new instance" do
      Person.auto_post?.should be true
      
      Person.exist?(@name).should be false
      p = Person.new(:name => @name, :age => 10)
      Person.get(@name).name.should eql @name
      p.delete
    end

    it "should reject auto-post of a new instance with an existing key" do
      p = Person.new(:name => @name, :age => 10)
      duplicate_key = lambda {Person.new(:name => p.name, :age => 0)}
      duplicate_key.should raise_error(JiakResourceException,/exist/)
      p.delete
    end
  end
end

describe "JiakResource class auto-update" do
  DogData = JiakDataHash.create(:name,:age)
  DogData.keygen :name
  class Dog
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'dogs'
    data_class   DogData
    auto_post    true
    auto_update  true
  end

  before do
    @pname = 'p auto-update'
    @c1name = 'c1 auto-update'
    @c2name = 'c2 auto-update'
    @p = Dog.new(:name => @pname, :age => 10)
    @c1 = Dog.new(:name => @cname, :age => 4)
    @c2 = Dog.new(:name => @cname, :age => 4)
  end
  
  after do
    @p.delete
    @c1.delete
    @c2.delete
    Dog.auto_update true
  end

  it "should auto-update local changes" do
    Dog.get(@pname).age.should eql 10
    @p.age = 12
    Dog.get(@pname).age.should eql 12

    Dog.get(@pname).name.should eql @pname
    @p.name = @pname.upcase
    Dog.get(@pname).name.should eql @pname.upcase

    @p.walk(Dog,'pup').size.should eql 0
    @p.link(@c1,'pup')
    @p.walk(Dog,'pup').size.should eql 1

    [@c1,@c2].each {|c| c.walk(Dog,'sibling').size.should eql 0}
    @c1.bi_link(@c2,'sibling')
    [@c1,@c2].each {|c| c.walk(Dog,'sibling').size.should eql 1}
  end

  it "should allow instance level override of class level auto-update true" do
    @p.auto_update?.should be nil
    
    Dog.get(@pname).age.should eql 10
    @p.auto_update = false
    @p.auto_update?.should be false
    @p.age = 12
    Dog.get(@pname).age.should eql 10
    @p.update
    Dog.get(@pname).age.should eql 12
    
    [@c1,@c2].each {|c| c.walk(Dog,'sibling').size.should eql 0}
    @c2.auto_update = false
    @c1.bi_link(@c2,'sibling')
    @c1.walk(Dog,'sibling').size.should eql 1
    @c2.walk(Dog,'sibling').size.should eql 0
  end

  it "should allow instance level override of class level auto-update false" do
    Dog.auto_update false
    
    Dog.get(@pname).age.should eql 10
    @p.auto_update = true
    @p.auto_update?.should be true
    @p.age = 12
    Dog.get(@pname).age.should eql 12
    
    [@c1,@c2].each {|c| c.walk(Dog,'sibling').size.should eql 0}
    @c2.auto_update = true
    @c1.bi_link(@c2,'sibling')
    @c1.walk(Dog,'sibling').size.should eql 0
    @c2.walk(Dog,'sibling').size.should eql 1
  end

  it "should allow instance level deferring back to class level" do
    Dog.get(@pname).age.should eql 10
    @p.auto_update = false
    @p.age = 12
    Dog.get(@pname).age.should eql 10
    @p.update
    Dog.get(@pname).age.should eql 12
    
    @p.auto_update = nil
    @p.auto_update?.should be nil
    @p.age = 10
    Dog.get(@pname).age.should eql 10
  end

end

describe "JiakResource simple" do
  DogData = JiakDataHash.create(:name,:age)
  DogData.keygen :name
  class Dog
    include JiakResource
    server       'http://localhost:8002/jiak'
    group        'dogs'
    data_class   DogData
    auto_post    true
    auto_update  true
  end

  before do
    @pname = 'p'
    @c1name = 'c1'
    @c2name = 'c2'
    @p = Dog.new(:name => @pname, :age => 10)
    @c1 = Dog.new(:name => @c1name, :age => 4)
    @c2 = Dog.new(:name => @c2name, :age => 4)
  end
  
  after do
    @p.delete
    @c1.delete
    @c2.delete
  end

  it "should do basic interaction and single-step relationships" do
    Dog.exist?(@pname).should be true
    Dog.get(@pname).should eql @p

    @p.name.should eql @pname
    @p.age.should eql 10
    
    @p.age = 11
    @p = Dog.get(@pname)
    @p.age.should eql 11

    [@c1,@c2].each {|c| @p.link(c,'pup')}
    pups = @p.walk(Dog,'pup')
    pups.size.should eql 2
    same_elements = pups.map {|c| c.name}.same_elements?([@c1.name,@c2.name])
    same_elements.should be true

    @c1.bi_link(@c2,'sibling')
    [@c1,@c2].each {|c| c.walk(Dog,'sibling').size.should eql 1}
    @c1.walk(Dog,'sibling')[0].should eql @c2
    @c2.walk(Dog,'sibling')[0].should eql @c1

    @c1.remove_link(@c2,'sibling')
    @c1.walk(Dog,'sibling').size.should eql 0
    @c2.walk(Dog,'sibling').size.should eql 1

    [@c1,@c2].each {|c| c.link(@p,'parent')}

    @c1.walk(Dog).size.should eql 1
    @c2.walk(Dog).size.should eql 2
    @c2.walk(Dog,'sibling').size.should eql 1
    @c2.walk(Dog,'parent').size.should eql 1
  end
end

describe "JiakResource complex" do
  PersonData = JiakDataHash.create(:name)
  PersonData.keygen :name

  class Parent
    include JiakResource
    
    server      'http://localhost:8002/jiak'
    group       'parents'
    data_class  PersonData
  end
  Child = Parent.copy(:group => 'children')

  it "should do multi-step relationships" do
    # relationships
    parent_children = {
      'p0' => ['c0'],
      'p1' => ['c0','c1','c2'],
      'p2' => ['c2','c3'],
      'p3' => ['c3'],
      'p4' => ['c4']
    }
    # invert relationships
    child_parents = parent_children.inject({}) do |build, (p,cs)|
      cs.each do |c|
        build[c] ? build[c] << p : build[c] = [p]
      end
      build
    end

    # store data and relationships
    parent_children.each do |pname,cnames|
      p = Parent.new(:name => pname).post
      cnames.each do |cname|
        begin
          c = Child.get(cname)
        rescue
          c = Child.new(:name => cname)
        end
        c.link(p,'parent')
        c.put
        p.link(c,'child')
      end
      p.update
    end

    parents  = parent_children.keys.map {|p| Parent.get(p)}
    children = child_parents.keys.map {|c| Child.get(c)}
    c0,c1,c2,c3,c4 = children

    # siblings
    c0s,c1s,c2s,c3s,c4s = children.map do |c|
      c.walk(Parent,'parent',Child,'child').delete_if{|s| s.eql?(c)}
    end
    c0s.size.should eql 2
    c1s.size.should eql 2
    c2s.size.should eql 3
    c3s.size.should eql 1
    c4s.size.should eql 0

    # check c2 siblings
    c2s_names = [c0.name,c1.name,c3.name]
    same_elements = c2s.map {|c| c.name}.same_elements?(c2s_names)
    same_elements.should be true

    # c3's step-sibling's other parent?
    c3sp = c3.walk(Parent,'parent',Child,'child',Parent,'parent')
    c3.walk(Parent,'parent').each {|p| c3sp.delete_if{|sp| p.eql?(sp)}}
    c3sp[0].name.should eql parents[1].name

    # add sibling links
    Child.auto_update true
    children.each do |c|
      siblings = c.walk(Parent,'parent',Child,'child').delete_if{|s| s.eql?(c)}
      siblings.each {|s| c.link(s,'sibling')}
    end
    c0.walk(Child,'sibling').size.should eql 2
    c1.walk(Child,'sibling').size.should eql 2
    c2.walk(Child,'sibling').size.should eql 3
    c3.walk(Child,'sibling').size.should eql 1
    c4.walk(Child,'sibling').size.should eql 0

    parents.each {|p| p.delete}
    children.each {|c| c.delete}
  end
end

# CxINC Many more tests to go
