require 'rails/version'
case Rails::VERSION::MAJOR
when 3
  require 'abstract_unit_rails3.rb'
when 4
  require 'abstract_unit_rails4.rb'
end

require 'minitest/autorun'
require 'mocha'
require 'mocha/mini_test'
require 'cookie_store_for_migration'
