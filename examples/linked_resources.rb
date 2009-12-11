require File.dirname(__FILE__) + '/example_helper.rb'

# The parent-child relationships
parent_children = {
  'p0' => ['c0'],
  'p1' => ['c0','c1','c2'],
  'p2' => ['c2','c3'],
  'p3' => ['c3']
}

# Simple resource classes. Parent group (Jiak bucket name) defaults to
# lowercase of class name, so Child class just like Parent, but grouped by
# 'child' rather than 'parent'.
class Parent
  include JiakResource
  server         SERVER_URI
  attr_accessor :name
  keygen { name }
end
(Child = Parent.dup).group 'child'

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

# Retrieve parents and children objects for future reference
parents  = parent_children.keys.map {|p| Parent.get(p)}
children = parent_children.values.flatten.uniq.map {|c| Child.get(c)}

# Retrieve parent-1 children by query
p1c = parents[1].query([Child,'child'])
puts "   3 children? #{p1c.size == 3}"                           # => true
puts " Including c2? #{p1c.include?(children[2])}"               # => true

# Retrieve child-3 parents by query
c3p = children[3].query([Parent,'parent'])
puts "    2 parents? #{c3p.size == 2}"                           # => true
puts " Including p2? #{c3p.include?(parents[2])}"                # => true

# Retrieve child-2 siblings by multi-step query
c2s = children[2].query([Parent,'parent',Child,'child'])
c2s.delete_if{|s| s.eql?(children[2])}
puts "   3 siblings? #{c2s.size == 3}"                           # => true
puts " Including c0? #{c2s.include?(children[0])}"               # => true

# Who is c3's step-sibling's other parent?
c3sp = children[3].query([Parent,'parent',Child,'child',Parent,'parent'])
c3p.each {|p| c3sp.delete_if{|sp| p.eql?(sp)}}
puts "    Parent p1? #{c3sp.include?(parents[1])}"               # => true

# Add sibling links using existing links (say, for convenience)
children.each do |c|
  siblings = c.query([Parent,'parent',Child,'child']).delete_if{|s| s.eql?(c)}
  siblings.each {|s| c.link(s,'sibling')}
  c.update
end

# Retrieve child-2 siblings using new links
c2s = children[2].query([Child,'sibling'])
puts "   3 siblings? #{c2s.size == 3}"                           # => true
puts " Including c0? #{c2s.include?(children[0])}"               # => true

# Clean-up by deleting all parents and children
parents.each  {|p| p.delete}
children.each {|c| c.delete}
