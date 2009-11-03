require 'riakrest'
include RiakRest

PersonData = JiakDataHash.create(:name)
PersonData.keygen :name

class Parent
  include JiakResource

  server      'http://localhost:8002/jiak'
  group       'parents'
  data_class  PersonData
end
Child = Parent.copy(:group => 'children')

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

# retrieve parents
parents = parent_children.keys.map {|p| Parent.get(p)}
p0,p1,p2,p3 = parents
puts p1.name                                # => 'p1'

# retrieve children
children = child_parents.keys.map {|c| Child.get(c)}
c0,c1,c2,c3 = children
puts c1.name                                # => 'c1'

# retrieve parent children
p0c,p1c,p2c,p3c = parents.map {|p| p.query(Child,'child')}
puts p2c[0].name                            # => 'c2' (not sorted, could be 'c3')

# retrieve children parents
c0p,c1p,c2p,c3p = children.map {|c| c.query(Parent,'parent')}
puts c3p[0].name                            # => 'p3'

# retrieve children siblings
c0s,c1s,c2s,c3s = children.map do |c|
  c.query(Parent,'parent',Child,'child').delete_if{|s| s.eql?(c)}
end
puts c3s[0].name                            # => 'c2'

# who is c3's step-sibling's other parent?
c3sp = c3.query(Parent,'parent',Child,'child',Parent,'parent')
c3p.each {|p| c3sp.delete_if{|sp| p.eql?(sp)}}
puts c3sp[0].name                           # => "p1"

# turn on auto-update at class level
Parent.auto_update true
Child.auto_update  true

# add sibling links
children.each do |c|
  siblings = c.query(Parent,'parent',Child,'child').delete_if{|s| s.eql?(c)}
  siblings.each {|s| c.link(s,'sibling')}
  c.update
end
puts c1.query(Child,'sibling').size          # => 2  
  
# some folks are odd, and others are normal
parent_children.keys.each do |p|
  parent = Parent.get(p)
  p_children = parent.query(Child,'child')
  p_children.each do |child| 
    child.link(parent, p[1].to_i.odd? ? 'odd' : 'normal')
    child.update
    parent.link(child, child.name[1].to_i.odd? ? 'odd' : 'normal')
  end
  parent.update
end
# refresh parents and children variables
parents.each {|p| p.refresh}
children.each {|c| c.refresh}

# do any odd parents have normal children?
op = parents.inject([]) do |build,parent|
  build << parent.query(Child,'normal',Parent,'odd')
  build.flatten.uniq
end
puts op[0].name                            # => 'p1'

# clean-up by deleting everybody
parents.each  {|p| p.delete}
children.each {|c| c.delete}
