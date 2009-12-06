require File.dirname(__FILE__) + '/example_helper.rb'

# Simple resource classes. Parent group (Jiak bucket name) defaults to
# lowercase of class name, so Child class just like Parent, but in a different
# group.
class Parent
  include JiakResource
  server         SERVER_URI
  attr_accessor :name
  keygen { name }
end
(Child = Parent.dup).group 'child'

# Some relationships to play with.
parent_children = {
  'p0' => ['c0'],
  'p1' => ['c0','c1','c2'],
  'p2' => ['c2','c3'],
  'p3' => ['c3']
}

# Invert relationships for comparison purposes.
child_parents = parent_children.inject({}) do |build, (p,cs)|
  cs.each do |c|
    build[c] ? build[c] << p : build[c] = [p]
  end
  build
end

# Store data and relationships
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

# Retrieve parents by key
parents = parent_children.keys.map {|p| Parent.get(p)}
p0,p1,p2,p3 = parents
puts " p1? #{p1.name.eql?('p1')}"                 # => true

# Retrieve children by key
children = child_parents.keys.map {|c| Child.get(c)}
c0,c1,c2,c3 = children
puts " c1? #{c1.name.eql?('c1')}"                 # => true

# Retrieve parent children by query
p0c,p1c,p2c,p3c = parents.map {|p| p.query([Child,'child'])}
puts " c2? #{p2c.include?(c2)}"                   # => true

# Retrieve children parents by query
c0p,c1p,c2p,c3p = children.map {|c| c.query([Parent,'parent'])}
puts " p2? #{c3p.include?(p2)}"                   # => true
puts " p3? #{c3p.include?(p3)}"                   # => true

# Retrieve children siblings by multi-step query
c0s,c1s,c2s,c3s = children.map do |c|
  c.query([Parent,'parent',Child,'child']).delete_if{|s| s.eql?(c)}
end
puts " c2? #{c3s.include?(c2)}"                   # => true

# Who is c3's step-sibling's other parent?
c3sp = c3.query([Parent,'parent',Child,'child',Parent,'parent'])
c3p.each {|p| c3sp.delete_if{|sp| p.eql?(sp)}}
puts " p1? #{c3sp.include?(p1)}"                  # => true

# Set auto-update at class level
Parent.auto_update true
Child.auto_update  true

# Add sibling links using existing links (say, for convenience)
children.each do |c|
  siblings = c.query([Parent,'parent',Child,'child']).delete_if{|s| s.eql?(c)}
  siblings.each {|s| c.link(s,'sibling')}
  c.update
end
qsize = c1.query([Child,'sibling']).size
puts "  #{qsize}? #{qsize == 2}"                 # => 2  
  
# Some folks are odd, and others are normal (example for link futzing)
parent_children.keys.each do |p|
  parent = Parent.get(p)
  p_children = parent.query([Child,'child'])
  p_children.each do |child| 
    child.link(parent, p[1].to_i.odd? ? 'odd' : 'normal')
    child.update
    parent.link(child, child.name[1].to_i.odd? ? 'odd' : 'normal')
  end
  parent.update
end
# Refresh parents and children variables
parents.each {|p| p.refresh}
children.each {|c| c.refresh}

# Do any odd parents have normal children?
op = parents.inject([]) do |build,parent|
  build << parent.query([Child,'normal',Parent,'odd'])
  build.flatten.uniq
end
puts " p1? #{op.include?(p1)}"                    # => true

# Clean-up by deleting all parents and children
parents.each  {|p| p.delete}
children.each {|c| c.delete}
