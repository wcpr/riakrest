# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{riakrest}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Rogers"]
  s.date = %q{2009-10-06}
  s.description = %q{CxTBD Not in working order yet.}
  s.email = ["paul@dingosky.com"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "PostInstall.txt"]
  s.files = ["History.txt", "Manifest.txt", "PostInstall.txt", "README.rdoc", "Rakefile", "lib/riakrest.rb", "lib/riakrest/exceptions.rb", "lib/riakrest/jiak_client.rb", "lib/riakrest/jiak_link.rb", "lib/riakrest/jiak_object.rb", "script/console", "script/destroy", "script/generate", "spec/riakrest_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "tasks/rspec.rake"]
  s.homepage = %q{http://github.com/dingosky/riakrest}
  s.post_install_message = %q{PostInstall.txt}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{riakrest}
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{CxTBD Not in working order yet.}

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
