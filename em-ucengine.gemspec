Gem::Specification.new do |s|
  s.name             = "em-ucengine"
  s.version          = "0.1.0"
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
  s.add_dependency "eventmachine", "~>0.12"
  s.add_dependency "em-http-request", "~>0.3"
  s.add_development_dependency "rspec", "~>2.4"
end
