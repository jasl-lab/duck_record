$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "duck_record/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "duck_record"
  s.version     = DuckRecord::VERSION
  s.authors     = ["jasl"]
  s.email       = ["jasl9187@hotmail.com"]
  s.homepage    = "https://github.com/jasl-lab/duck_record"
  s.summary     = "Used for creating virtual models like ActiveType or ModelAttribute does"
  s.description = <<-DESC.strip
    It looks like Active Record and quacks like Active Record, but it can't do persistence or querying,
    it's Duck Record!
    Actually it's extract from Active Record.
    Used for creating virtual models like ActiveType or ModelAttribute does.
  DESC
  s.license     = "MIT"

  s.platform    = Gem::Platform::RUBY
  s.required_ruby_version = ">= 2.2.2"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "activesupport", "~> 5.0"
  s.add_dependency "activemodel",   "~> 5.0"

  s.add_development_dependency "rails", "~> 5.0"
  s.add_development_dependency "sqlite3"
end
