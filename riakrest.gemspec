# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{riakrest}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Rogers"]
  s.date = %q{2009-10-29}
  s.description = %q{RiakRest provides structured, RESTful interaction with a Riak document
store. In Riak parlance, this JSON data exchange is called Jiak. RiakRest
provides two levels of interaction: Core Client and Resource. Core Client
interaction works down at the Jiak level and exposes Jiak internals. Resource
interaction is an abstraction built on top of the Core Client.}
  s.email = ["paul@dingosky.com"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "PostInstall.txt"]
  s.files = ["History.txt", "Manifest.txt", "PostInstall.txt", "README.rdoc", "Rakefile", "examples/auto_update_data.rb", "examples/auto_update_links.rb", "examples/basic_client.rb", "examples/basic_resource.rb", "examples/json_data_resource.rb", "examples/linked_resource.rb", "examples/multiple_resources.rb", "lib/riakrest.rb", "lib/riakrest/core/exceptions.rb", "lib/riakrest/core/jiak_bucket.rb", "lib/riakrest/core/jiak_client.rb", "lib/riakrest/core/jiak_data.rb", "lib/riakrest/core/jiak_link.rb", "lib/riakrest/core/jiak_object.rb", "lib/riakrest/core/jiak_schema.rb", "lib/riakrest/core/query_link.rb", "lib/riakrest/data/jiak_data_hash.rb", "lib/riakrest/resource/jiak_resource.rb", "lib/riakrest/version.rb", "riakrest.gemspec", "script/console", "script/destroy", "script/generate", "spec/core/exceptions_spec.rb", "spec/core/jiak_bucket_spec.rb", "spec/core/jiak_client_spec.rb", "spec/core/jiak_link_spec.rb", "spec/core/jiak_object_spec.rb", "spec/core/jiak_schema_spec.rb", "spec/core/query_link_spec.rb", "spec/data/jiak_data_hash_spec.rb", "spec/resource/jiak_resource_spec.rb", "spec/riakrest_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "tasks/rspec.rake"]
  s.homepage = %q{http://github.com/wcpr/riakrest}
  s.post_install_message = %q{PostInstall.txt}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{riakrest}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{RiakRest provides structured, RESTful interaction with a Riak document store}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 2.3.3"])
    else
      s.add_dependency(%q<hoe>, [">= 2.3.3"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 2.3.3"])
  end
end
