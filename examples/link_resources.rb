
require 'lib/riakrest'
include RiakRest

Parent = JiakDataHash.create(:name)
class Parent
  def keygen
    name
  end
end
       
Child = JiakDataHash.create(:name)
class Child
  def keygen
    name
  end
end

{ 'p1' => ['c1','c2'],
  'p2' => ['c2','c3'],
  'p3' => ['c4','c5','c6'],
  'p4' => ['c4','c5','c6']
}.each do |p_name,c_names|
  parent = Parent.new(:name => p_name)
  parent.post
  c_names.each do |c_name|
    begin
      child = Child.get(c_name)
      
      child.parents << parent
    rescue JiakResourceNotFound
      child = Child.new(:name => c_name, :parents => [parent])
    end
  end
end

