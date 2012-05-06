require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "jekyll-epub"
    gem.summary = %Q{Create an eBook (epub) of your Jekyll blog}
    gem.description = %Q{Create an eBook (epub) of your Jekyll blog}
    gem.email = "gregoire.lejeune@free.fr"
    gem.homepage = "http://github.com/glejeune/jekyll-epub"
    gem.authors = ["Gregoire Lejeune"]

    gem.add_dependency 'mime-types', ">= 0"
    gem.add_dependency 'uuid', ">= 0"
    gem.add_dependency 'jekyll', ">= 0"
    gem.add_dependency 'libxml-ruby', ">= 0"

    gem.add_development_dependency "shoulda", ">= 0"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "jekyll-epub #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
