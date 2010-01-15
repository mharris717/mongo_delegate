require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "mongo_delegate"
    gem.summary = %Q{wrapper around multiple MongoDB collection, allowing programs to treat them as a single combined collection}
    gem.description = %Q{wrapper around multiple MongoDB collection, allowing programs to treat them as a single combined collection}
    gem.email = "mharris717@gmail.com"
    gem.homepage = "http://github.com/mharris717/mongo_delegate"
    gem.authors = ["Mike Harris"]
    gem.add_development_dependency "rspec"
    gem.add_development_dependency "rr"
    %w(mharris_ext andand fattr mongo mongo_scope activesupport).each { |x| gem.add_dependency x }
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

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

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "mongo_delegate #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

Jeweler::GemcutterTasks.new
