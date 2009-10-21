begin
  require 'spec'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'riakrest'
include RiakRest

def same_elements(arr1,arr2)
  arr1.size != arr2.size ? false :
    arr1.reduce(true) {|same,value| same && arr2.include?(value)}
end

def same_fields(arr1,arr2)
  same_elements(arr1.map{|f| f.to_s}, arr2.map{|f| f.to_s})
end

def symbolize_keys(hsh)
  hsh.inject({}) do |build, (key, value)|
    build[key.to_sym] = value
    build
  end
end
