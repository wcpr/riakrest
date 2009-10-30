= riakrest

http://github.com/wcpr/riakrest

== DESCRIPTION:

RiakRest provides structured, RESTful interaction with a Riak document
store.

== RIAK:

Riak[http://riak.basho.com] is an open-source project developed and maintained
by the fine folks at Basho[http://www.basho.com]. It combines a decentralized
key-value store, a flexible map/reduce engine, and a friendly HTTP/JSON query
interface to provide a database ideally suited for Web applications. RiakRest
interacts with the HTTP/JSON query interface, which is called Jiak.

== FEATURES/PROBLEMS:


== SYNOPSIS:

RiakRest provides structured, RESTful interaction with the HTTP/JSON interface
of a Riak[http://riak.basho.com] document data store. RiakRest provides two
levels of interaction: Core Client and Resource. Core Client works at the Jiak
level and exposes Jiak internals. JiakResource is an abstraction built on top
of the Core Client that gives a true RESTful feel.

== REQUIREMENTS:

RestClient is used for REST server interaction.<br/>
JSON is used for data exchange.<br/>
Riak[http://riak.basho.com] provides the HTTP/JSON Jiak interface and data store.

== INSTALL:

sudo gem install riakrest

== EXAMPLE
<code>
  require 'riakrest'
  include RiakRest
  
  PersonData = JiakDataHash.create(:name,:age)
  PersonData.keygen :name
  
  class Person
    include JiakResource
    server      'http://localhost:8002/jiak'
    group       'people'
    data_class  PersonData
    auto_post   true
    auto_update true
  end
  
  remy = Person.new(:name => 'remy', :age => 10)  #            (auto-post)
  remy.name                                       # => "remy"  (auto-update)

  puts Person.get('remy').name                    # => "remy"  (from Jiak server)
  puts Person.get('remy').age                     # => 10      (from Jiak server)
  
  remy.age = 11                                   #            (auto-update)
  puts Person.get('remy').age                     # => 11      (from Jiak server)
  
  callie = Person.new(:name => 'Callie', :age => 13)
  remy.link(callie,'sister')
  
  sisters = remy.query(Person,'sister')
  sisters[0].eql?(callie)                         # => true
  
  remy.delete
  callie.delete
</code>

Go forth and Riak!

== LICENSE:

(The MIT License)

Copyright (c) 2009 Paul Rogers, DingoSky LLC

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
