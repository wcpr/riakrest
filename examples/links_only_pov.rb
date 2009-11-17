require 'riakrest'
include RiakRest

# class with 10 fields
class Fields
  include JiakResource
  server         'http://localhost:8002/jiak'
  jattr_accessor (0...10).map {|n| "f#{n}".to_sym}
  auto_manage
end

class Links
  include JiakResource
  server       'http://localhost:8002/jiak'
  auto_manage
end

# populate two Fields objects with (meaningless) stuff
Fields.pov
fields = ["fields1","fields2"]
fields1,fields2 =
  fields.map {|o| Fields.new(Fields.schema.write_mask.inject({}) do |h,f|
                               h[f]="#{o.upcase}-#{f.hash}"
                               h
                             end)}

Links.pov
links1 = Links.get(fields1.jiak.key)
links1.link(fields2,'link')

Fields.pov
fields2.f1 = "new f1"

linked = fields1.query(Fields,'link')[0]
puts linked.f1 == fields2.f1                        # => true

fields1.delete
fields2.delete
