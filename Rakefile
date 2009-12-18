require 'rubygems'
require 'rake'

begin
  require 'jeweler'
rescue LoadError
  puts "Jeweler (or a dependency) not available."
  puts "  Install with: sudo gem install jeweler"
end

Jeweler::Tasks.new do |gem|
  gem.name = "riakrest"
  gem.summary = %Q{RiakRest provides structured, RESTful interaction with a Riak document store.}
  gem.description = <<-EOS
    RiakRest provides structured, RESTful interaction with
    the HTTP/JSON interface of a Riak[http://riak.basho.com] document data
    store. RiakRest provides two levels of interaction: Core Client and
    Resource. Core Client works at the Jiak level and exposes Jiak
    internals. JiakResource is an abstraction built on top of the Core Client
    that gives a true RESTful feel.
  EOS
  gem.authors = ["Paul Rogers"]
  gem.email = "paul@riakrest.com"
  gem.homepage = "http://riakrest.com"
  gem.add_dependency('rest-client', '>= 1.0.0')
  gem.add_dependency('json', '>= 1.1.9')
  gem.add_development_dependency "rest-client", ">= 1.0.0"
  gem.add_development_dependency "json", ">= 1.1.9"
  gem.add_development_dependency "jeweler", ">= 1.4.0"
  gem.add_development_dependency "rspec", ">= 1.2.9"
end

Jeweler::GemcutterTasks.new

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :test => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "riakrest #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
