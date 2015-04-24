# This file from rails/actionpack
# MIT LICENSE
# Copyright (c) 2004-2015 David Heinemeier Hansson
require 'active_support/testing/autorun'
require 'abstract_controller'
require 'abstract_controller/railties/routes_helpers'
require 'action_controller'
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_dispatch'
require 'active_support/dependencies'
require 'active_model'
require 'active_record'
require 'action_controller/caching'

ActiveSupport::TestCase.test_order = :random

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

module ActionDispatch
  module SharedRoutes
    def before_setup
      @routes = SharedTestRoutes
      super
    end
  end
  # Hold off drawing routes until all the possible controller classes
  # have been loaded.
  module DrawOnce
    class << self
      attr_accessor :drew
    end
    self.drew = false
    def before_setup
      super
      return if DrawOnce.drew
      SharedTestRoutes.draw do
        get ':controller(/:action)'
      end
      ActionDispatch::IntegrationTest.app.routes.draw do
        get ':controller(/:action)'
      end
      DrawOnce.drew = true
    end
  end
end
class RoutedRackApp
  attr_reader :routes
  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk).build(@routes)
  end
  def call(env)
    @stack.call(env)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  include ActionDispatch::SharedRoutes
  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use "ActionDispatch::DebugExceptions"
      middleware.use "ActionDispatch::Callbacks"
      middleware.use "ActionDispatch::ParamsParser"
      middleware.use "ActionDispatch::Cookies"
      middleware.use "ActionDispatch::Flash"
      middleware.use "Rack::Head"
      yield(middleware) if block_given?
    end
  end
  self.app = build_app
  # Stub Rails dispatcher so it does not get controller references and
  # simply return the controller#action as Rack::Body.
  class StubDispatcher < ::ActionDispatch::Routing::RouteSet::Dispatcher
    protected
    def controller_reference(controller_param)
      controller_param
    end
    def dispatch(controller, action, env)
      [200, {'Content-Type' => 'text/html'}, ["#{controller}##{action}"]]
    end
  end
  def self.stub_controllers
    old_dispatcher = ActionDispatch::Routing::RouteSet::Dispatcher
    ActionDispatch::Routing::RouteSet.module_eval { remove_const :Dispatcher }
    ActionDispatch::Routing::RouteSet.module_eval { const_set :Dispatcher, StubDispatcher }
    yield ActionDispatch::Routing::RouteSet.new
  ensure
    ActionDispatch::Routing::RouteSet.module_eval { remove_const :Dispatcher }
    ActionDispatch::Routing::RouteSet.module_eval { const_set :Dispatcher, old_dispatcher }
  end
  def with_routing(&block)
    temporary_routes = ActionDispatch::Routing::RouteSet.new
    old_app, self.class.app = self.class.app, self.class.build_app(temporary_routes)
    old_routes = SharedTestRoutes
    silence_warnings { Object.const_set(:SharedTestRoutes, temporary_routes) }
    yield temporary_routes
  ensure
    self.class.app = old_app
    self.remove!
    silence_warnings { Object.const_set(:SharedTestRoutes, old_routes) }
  end
  def with_autoload_path(path)
    path = File.join(File.dirname(__FILE__), "fixtures", path)
    if ActiveSupport::Dependencies.autoload_paths.include?(path)
      yield
    else
      begin
        ActiveSupport::Dependencies.autoload_paths << path
        yield
      ensure
        ActiveSupport::Dependencies.autoload_paths.reject! {|p| p == path}
        ActiveSupport::Dependencies.clear
      end
    end
  end
end

