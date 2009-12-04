require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "JiakResource default" do
  class Rsrc           # :nodoc:
    include JiakResource
    server        SERVER_URI
    attr_accessor :f1, :f2
  end

  before do
    @server_uri = SERVER_URI
    @group = 'rsrc'
    @schema = JiakSchema.new [:f1,:f2]
  end

  describe "class creation" do
    it "should respond to" do
      Rsrc.should respond_to(:server,:group)
      Rsrc.should respond_to(:attr_reader,:attr,:attr_writer,:attr_accessor)
      Rsrc.should respond_to(:params,:auto_update,:keys)
      Rsrc.should respond_to(:schema,:push_schema,:server_schema?)
      Rsrc.should respond_to(:post,:put,:get,:delete)
      Rsrc.should respond_to(:refresh,:update,:exist?)
      Rsrc.should respond_to(:link,:bi_link,:query,:walk)
      Rsrc.should respond_to(:auto_post,:auto_update,:auto_manage)
      Rsrc.should respond_to(:auto_post,:auto_update,:auto_manage?)
      Rsrc.jiak.should respond_to(:client,:uri,:group,:data,:bucket)
    end
    
    it "should have specified settings" do
      Rsrc.params.should be_empty
      Rsrc.auto_update?.should be false
      Rsrc.schema.should eql @schema
      
      Rsrc.jiak.should be_a Struct
      Rsrc.jiak.client.should be_a JiakClient
      Rsrc.jiak.uri.should eql @server_uri
      Rsrc.jiak.group.should eql @group
      Rsrc.jiak.data.should include JiakData
      Rsrc.jiak.bucket.should be_a JiakBucket
      Rsrc.jiak.bucket.name.should eql @group
      Rsrc.jiak.auto_post.should be false
      Rsrc.jiak.auto_update.should be false
    end
  end

  describe "instance creation" do
    before do
      @rsrc = Rsrc.new
    end

    it "should respond to" do
      @rsrc.should respond_to(:jiak)
      @rsrc.should respond_to(:auto_update=,:auto_update?)
      @rsrc.should respond_to(:post,:put,:delete)
      @rsrc.should respond_to(:update,:push,:refresh,:pull)
      @rsrc.should respond_to(:local?)
      @rsrc.should respond_to(:link,:bi_link,:query,:walk)
      @rsrc.should respond_to(:eql?,:==)

      @rsrc.should respond_to(:f1,:f2)
    end
    
    it "should have default settings" do
      @rsrc.jiak.should be_a Struct
      @rsrc.jiak.should respond_to(:object,:auto_update)

      @rsrc.jiak.object.should be_a JiakObject
      @rsrc.jiak.object.bucket.should be_a JiakBucket
      @rsrc.jiak.object.bucket.name.should eql @group
      
      @rsrc.jiak.auto_update.should be_nil
    end
  end
end

describe "JiakResource schema" do
  class People           # :nodoc:
    include JiakResource
    server         SERVER_URI
    group          'schema'
    attr_accessor  :name, :age
    keygen { name }
  end

  it "should have data schema" do
    jiak_schema = JiakSchema.new([:name,:age])
    People.schema.should eql jiak_schema
  end

  it "should push/check server schema" do
    People.server_schema?.should be false
    People.push_schema
    People.server_schema?.should be true

    People.push_schema(JiakSchema::WIDE_OPEN)
    People.server_schema?.should be false
  end
end

describe "JiakResource default class-level auto-post/auto-update" do
  class People           # :nodoc:
    include JiakResource
    server         SERVER_URI
    group          'people'
    attr_accessor  :name, :age
    keygen { name }
  end

  before do
    @name = 'p default'
    @p = People.new(:name => @name, :age => 10)
  end

  it "should create instance without posting" do
    People.auto_post?.should be false
    
    People.exist?(@name).should be false
    @p.local?.should be true
    @p.post
    People.get(@name).name.should eql @name
    @p.local?.should be false
    @p.delete
  end

  it "should change local data without updating" do
    @p.post
    People.get(@name).age.should eql 10
    @p.age = 12
    People.get(@name).age.should eql 10
    @p.update
    People.get(@name).age.should eql 12
    @p.delete
  end

  it "should check if resource is local and if it exists on server" do
    name = 'p local'
    p = People.new(:name => name)
    p.local?.should be true
    People.exist?(name).should be false

    p.post
    p.local?.should be false
    People.exist?(name).should be true

    p.delete
  end
end

describe "JiakResource class auto-post" do
  class People           # :nodoc:
    include JiakResource
    server         SERVER_URI
    group          'people'
    attr_accessor  :name, :age
    keygen { name }
  end

  before do
    @name = 'p auto-post'
  end

  describe "false" do
    before do
      People.auto_post false
    end

    it "should not auto-post, or auto-update a local object" do
      People.auto_post?.should be false

      People.exist?(@name).should be false

      People.auto_update true
      p = People.new(:name => @name, :age => 10)
      p.local?.should be true
      p.age = 12
      p.local?.should be true

      q = People.new(:name => 'q', :age => 20)

      link_to_local = lambda {p.link(q,'link')}
      link_to_local.should raise_error(JiakResourceException,/local/)
      q.post

      q.local?.should be false

      p.link(q,'link')
      p.local?.should be true
      p.jiak.object.links.size.should be 1

      p.post
      p.local?.should be false
      p.age.should be 12
      People.get(@name).age.should be 12
      p.query([People,'link'])[0].should eql q
      
      p.age = 10
      People.get(@name).age.should be 10

      p.delete
      q.delete
    end
  end

  describe "true" do
    before do
      People.auto_post true
    end

    it "should auto-post a new instance" do
      People.auto_post?.should be true
      
      People.exist?(@name).should be false
      p = People.new(:name => @name, :age => 10)
      People.get(@name).name.should eql @name
      p.delete
    end

    it "should reject auto-post of a new instance with an existing key" do
      p = People.new(:name => @name, :age => 10)
      duplicate_key = lambda {People.new(:name => p.name, :age => 0)}
      duplicate_key.should raise_error(JiakResourceException,/exist/)
      p.delete
    end
  end
end

describe "JiakResource class auto-update" do
  class Dogs           # :nodoc:
    include JiakResource
    server         SERVER_URI
    group          'dogs'
    attr_accessor  :name, :age
    keygen { name }
    auto_manage
  end

  before do
    @pname = 'p auto-update'
    @c1name = 'c1 auto-update'
    @c2name = 'c2 auto-update'
    @p = Dogs.new(:name => @pname, :age => 10)
    @c1 = Dogs.new(:name => @cname, :age => 4)
    @c2 = Dogs.new(:name => @cname, :age => 4)
  end
  
  after do
    @p.delete
    @c1.delete
    @c2.delete
    Dogs.auto_update true
  end

  it "should auto-update local changes" do
    Dogs.get(@pname).age.should eql 10
    @p.age = 12
    Dogs.get(@pname).age.should eql 12

    Dogs.get(@pname).name.should eql @pname
    @p.name = @pname.upcase
    Dogs.get(@pname).name.should eql @pname.upcase

    @p.query([Dogs,'pup']).size.should eql 0
    @p.link(@c1,'pup')
    @p.query([Dogs,'pup']).size.should eql 1

    [@c1,@c2].each {|c| c.query([Dogs,'sibling']).size.should eql 0}
    @c1.bi_link(@c2,'sibling')
    [@c1,@c2].each {|c| c.query([Dogs,'sibling']).size.should eql 1}
  end

  it "should allow instance level override of class level auto-update true" do
    @p.auto_update?.should be nil
    
    Dogs.get(@pname).age.should eql 10
    @p.auto_update = false
    @p.auto_update?.should be false
    @p.age = 12
    Dogs.get(@pname).age.should eql 10
    @p.update
    Dogs.get(@pname).age.should eql 12
    
    [@c1,@c2].each {|c| c.query([Dogs,'sibling']).size.should eql 0}
    @c2.auto_update = false
    @c1.bi_link(@c2,'sibling')
    @c1.query([Dogs,'sibling']).size.should eql 1
    @c2.query([Dogs,'sibling']).size.should eql 0
  end

  it "should allow instance level override of class level auto-update false" do
    Dogs.auto_update false
    
    Dogs.get(@pname).age.should eql 10
    @p.auto_update = true
    @p.auto_update?.should be true
    @p.age = 12
    Dogs.get(@pname).age.should eql 12
    
    [@c1,@c2].each {|c| c.query([Dogs,'sibling']).size.should eql 0}
    @c2.auto_update = true
    @c1.bi_link(@c2,'sibling')
    @c1.query([Dogs,'sibling']).size.should eql 0
    @c2.query([Dogs,'sibling']).size.should eql 1
  end

  it "should allow instance level deferring back to class level" do
    Dogs.get(@pname).age.should eql 10
    @p.auto_update = false
    @p.age = 12
    Dogs.get(@pname).age.should eql 10
    @p.update
    Dogs.get(@pname).age.should eql 12
    
    @p.auto_update = nil
    @p.auto_update?.should be nil
    @p.age = 10
    Dogs.get(@pname).age.should eql 10
  end

end

describe "JiakResource simple" do
  class Dogs           # :nodoc:
    include JiakResource
    server         SERVER_URI
    group          'dogs'
    attr_accessor  :name, :age
    keygen { name }
    auto_manage
  end

  before do
    @pname = 'p'
    @c1name = 'c1'
    @c2name = 'c2'
    @p = Dogs.new(:name => @pname, :age => 10)
    @c1 = Dogs.new(:name => @c1name, :age => 4)
    @c2 = Dogs.new(:name => @c2name, :age => 4)
  end
  
  after do
    @p.delete
    @c1.delete
    @c2.delete
  end

  it "should do basic interaction and single-step relationships" do
    Dogs.exist?(@pname).should be true
    Dogs.get(@pname).should eql @p

    @p.name.should eql @pname
    @p.age.should eql 10
    
    @p.age = 11
    @p = Dogs.get(@pname)
    @p.age.should eql 11

    [@c1,@c2].each {|c| @p.link(c,'pup')}
    pups = @p.query([Dogs,'pup'])
    pups.size.should eql 2
    same_elements = pups.map {|c| c.name}.same_elements?([@c1.name,@c2.name])
    same_elements.should be true

    @c1.bi_link(@c2,'sibling')
    [@c1,@c2].each {|c| c.query([Dogs,'sibling']).size.should eql 1}
    @c1.query([Dogs,'sibling'])[0].should eql @c2
    @c2.query([Dogs,'sibling'])[0].should eql @c1

    @c1.remove_link(@c2,'sibling')
    @c1.query([Dogs,'sibling']).size.should eql 0
    @c2.query([Dogs,'sibling']).size.should eql 1

    [@c1,@c2].each {|c| c.link(@p,'parent')}

    @c1.query([Dogs,QueryLink::ANY]).size.should eql 1
    @c2.query([Dogs,QueryLink::ANY]).size.should eql 2
    @c2.query([Dogs,'sibling']).size.should eql 1
    @c2.query([Dogs,'parent']).size.should eql 1
  end
end

describe "JiakResource complex" do
  class Parents           # :nodoc:
    include JiakResource
    server        SERVER_URI
    attr_accessor :name
    keygen { name }
  end

  Children = Parents.dup
  Children.group 'children'

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
      p = Parents.new(:name => pname).post
      cnames.each do |cname|
        begin
          c = Children.get(cname)
        rescue
          c = Children.new(:name => cname)
        end
        c.link(p,'parent')
        c.put
        p.link(c,'child')
      end
      p.update
    end

    parents  = parent_children.keys.map {|p| Parents.get(p)}
    children = child_parents.keys.map {|c| Children.get(c)}
    c0,c1,c2,c3,c4 = children

    # siblings
    c0s,c1s,c2s,c3s,c4s = children.map do |c|
      c.query([Parents,'parent',Children,'child']).delete_if{|s| s.eql?(c)}
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
    c3sp = c3.query([Parents,'parent',Children,'child',Parents,'parent'])
    c3.query([Parents,'parent']).each {|p| c3sp.delete_if{|sp| p.eql?(sp)}}
    c3sp[0].name.should eql parents[1].name

    # add sibling links
    Children.auto_update true
    children.each do |c|
      siblings = 
        c.query([Parents,'parent',Children,'child']).delete_if{|s| s.eql?(c)}
      siblings.each {|s| c.link(s,'sibling')}
    end
    sibling_query = [Children,'sibling']
    c0.query(sibling_query).size.should eql 2
    c1.query(sibling_query).size.should eql 2
    c2.query(sibling_query).size.should eql 3
    c3.query(sibling_query).size.should eql 1
    c4.query(sibling_query).size.should eql 0

    parents.each  {|p| p.delete}
    children.each {|c| c.delete}
  end
end

