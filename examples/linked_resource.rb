require 'lib/riakrest'
include RiakRest

PersonData = JiakDataHash.create(:name)
class PersonData
  def keygen
    name
  end
end

class Parent
  include JiakResource
  server   'http://localhost:8002/jiak'
  resource :name => 'parent',
           :data_class => PersonData
end

Child = Parent.copy(:name => 'child')

# relationships
parent_children = {
  'p0' => ['c0'],
  'p1' => ['c0','c1','c2'],
  'p2' => ['c2','c3'],
  'p3' => ['c3']
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
  p = Parent.new(:name => pname)
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
  p.post
end

# retrieve parents
parents = parent_children.keys.map {|p| Parent.get(p)}
p0,p1,p2,p3 = parents

# retrieve children
children = child_parents.keys.map {|c| Child.get(c)}
c0,c1,c2,c3 = children

# retrieve parent children
p0c,p1c,p2c,p3c = parents.map {|p| p.walk(Child,'child')}

# retrieve children parents
c0p,c1p,c2p,c3p = children.map {|c| c.walk(Parent,'parent')}

# retrieve children siblings
c0s,c1s,c2s,c3s = children.map do |c|
  c.walk(Parent,'parent',Child,'child').delete_if{|s| s.eql?(c)}
end

# who is c3's step-sibling's other parent?
c3sp = c3.walk(Parent,'parent',Child,'child',Parent,'parent')
c3p.each {|p| c3sp.delete_if{|sp| p.eql?(sp)}}
c3sp[0].name                                      # => "p1"

# some folks are odd, and others are normal
parent_children.keys.each do |p|
  parent = Parent.get(p)
  p_children = parent.walk(Child,'child')
  p_children.each do |child| 
    child.link(parent, p[1].to_i.odd? ? 'odd' : 'normal')
    child.store
    parent.link(child, child.name[1].to_i.odd? ? 'odd' : 'normal')
  end
  parent.store
end
[p0,p1,p2,p3].each {|p| p.get}

# do any odd parents have normal children?
op = children.inject([]) do |build,child|
  build << child.walk(Parent,'odd',Child,'normal',Parent,'odd')
  build
end
op = op.flatten!.map{|p| p.name}.uniq
