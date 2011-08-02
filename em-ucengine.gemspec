Gem::Specification.new do |s|
  s.name             = "em-ucengine"
  s.version          = "0.2.0"
  s.date             = Time.now.utc.strftime("%Y-%m-%d")
  s.homepage         = "http://github.com/af83/ucengine.em"
  s.authors          = "Bruno Michel"
  s.email            = "bruno.michel@af83.com"
  s.description      = "A library for U.C.Engine, powered by EventMachine"
  s.summary          = "A library for U.C.Engine, powered by EventMachine"
  s.extra_rdoc_files = %w(README.md)
  s.files            = Dir["LICENSE", "README.md", "Gemfile", "lib/**/*.rb"]
  s.require_paths    = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.add_dependency "eventmachine", "1.0.0.beta3"
  s.add_dependency "em-http-request", "1.0.0.beta4"
  s.add_dependency "em-eventsource", "~>0.1.0"
  s.add_dependency "yajl-ruby", "~>0.8"
  s.add_dependency "multipart_body", "~>0.2"
  s.add_development_dependency "minitest", "~>2.0"
  s.add_development_dependency "bundler"
  s.add_development_dependency "rake"
end
