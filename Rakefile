require 'rubygems'
$:<< 'lib'
require 'webee'
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "webee"
  gem.homepage = "http://github.com/rubiojr/webee"
  gem.license = "MIT"
  gem.summary = %Q{Abiquo API Ruby Implementation}
  gem.description = %Q{Abiquo API Ruby Implementation}
  gem.email = "sergio@rubio.name"
  gem.authors = ["Sergio Rubio"]
  gem.version = WeBee::VERSION
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  gem.add_runtime_dependency 'sax-machine'
  gem.add_runtime_dependency 'rest-client'
  gem.add_runtime_dependency 'nokogiri'
  gem.add_runtime_dependency 'builder'
  gem.add_runtime_dependency 'alchemist'
  gem.add_runtime_dependency 'activesupport'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :build

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "webee #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
