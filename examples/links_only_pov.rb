require 'riakrest'
include RiakRest

# class with 10 fields
class Full
  include JiakResource
  server       'http://localhost:8002/jiak'
  group        'fields'
  data_class   JiakDataHash.create (0...10).map {|n| "f#{n}".to_sym}
  auto_post    true
  auto_update  true
end

# copy of above, but no read/write fields, i.e., only links
LinksOnly = JiakDataHash.create Full.schema
LinksOnly.readwrite []
Links = Full.copy(:data_class => LinksOnly)

# populate two Full objects with (meaningless) stuff
Full.pov
full1,full2 =
  ["full1","full2"].map {|o| Full.new(Full.schema.write_mask.inject({}) do |h,f|
                                        h[f]="#{o.upcase}-#{f.hash}"
                                        h
                                      end)}

Links.pov
links1 = Links.get(full1.jiak.key)
links1.link(full2,'link')

Full.pov
full2.f1 = "new f1"

linked = full1.query(Full,'link')[0]
puts linked.f1 == full2.f1                        # => true

full1.delete
full2.delete
