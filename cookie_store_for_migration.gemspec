$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "cookie_store_for_migration/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "cookie_store_for_migration"
  s.version     = CookieStoreForMigration::VERSION
  s.authors     = ["Masafumi Yabu"]
  s.email       = ["m.yabu@green-bell.jp"]
  s.homepage    = ""
  s.summary     = "CookieStore for migration"
  s.description = s.summary
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_development_dependency "rails", "~> 4.2.1"
  s.add_development_dependency "rspec-mocks"
end
