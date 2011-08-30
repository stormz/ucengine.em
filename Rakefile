require 'rake/testtask'
require 'yard'
require 'yard/rake/yardoc_task'

Rake::TestTask.new do |t|
  t.pattern = "spec/*_spec.rb"
end

desc "Builds the gem"
task :gem do
  Gem::Builder.new(eval(File.read('em-ucengine.gemspec'))).build
end

desc 'Generate Yardoc documentation'
task :doc => :yard

YARD::Rake::YardocTask.new do |yardoc|
   yardoc.name = 'yard'
   yardoc.options = ['--verbose']
   yardoc.files = [
     'lib/**/*.rb', 'ext/**/*.c', 'README', 'CHANGELOG', 'LICENSE'
   ]
end

task :default => :test
