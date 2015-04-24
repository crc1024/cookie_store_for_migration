require 'abstract_unit'
require 'active_support/key_generator'
require 'rspec/mocks'
require 'test_helper'

class CookieStoreForMigrationTest < ActionDispatch::IntegrationTest
  SessionSecret = 'e8316dc2ece70f9a179d9a75f7d556a1ce92fa0dc4eaf4676460ef604ad4a7981cd782bba7ceb402'
  Generator = ActiveSupport::LegacyKeyGenerator.new(SessionSecret)

  class SessionController < ActionController::Base
    def initialize_session
      session.send(:load!)
      render text: session
    end

    def store
      session[params[:key]] = params[:value]
      render text: 'hogehog'
    end

     def session_id
      render :text => session[:session_id]
    end

    def get
      render text: session[params[:key]].to_s
    end

    def keys
      render text: session.keys
    end
  end

  def test_migration_with_destroy
    source_cookie = nil
    with_test_route_set(ActionDispatch::Session::CookieStore, key: 'first_key') do
      get '/initialize_session'
      get '/session_id'
      get '/store', key: 'fuga', value: 'session_value!!!'
      assert cookies['first_key'].present?, 'have source session'
      source_cookie = cookies['first_key']
    end
    with_test_route_set(ActionDispatch::Session::CookieStoreForMigration, key: 'next_key', source_session_store: {
      session_store: ActionDispatch::Session::CookieStore,
      options: {
        key: 'first_key'
      },
      destroy: 'destroy'
    }) do
      cookies['first_key'] = source_cookie
      get '/initialize_session'
      assert cookies['next_key'].present?, 'create new session'
      assert cookies['destroy'].present?, 'have the destroy cookie'
      assert cookies['first_key'].present?, 'have the first session'
      get '/session_id'
      assert cookies['first_key'].blank?, 'expires source session'
      assert cookies['destroy'].blank?, 'expires the destroy cookie'
      get '/get', key: 'fuga'
      assert_equal body, 'session_value!!!'
    end
  end

  def test_migration_without_destroy
    source_cookie = nil
    with_test_route_set(ActionDispatch::Session::CookieStore, key: 'first_key') do
      get '/initialize_session'
      get '/store', key: 'fuga', value: 'session_value!!!'
      get '/session_id'
      assert cookies['first_key'].present?, 'have source session'
      source_cookie = cookies['first_key']
    end
    with_test_route_set(ActionDispatch::Session::CookieStoreForMigration, key: 'next_key', source_session_store: {
      session_store: ActionDispatch::Session::CookieStore,
      options: {
        key: 'first_key'
      }
    }) do
      cookies['first_key'] = source_cookie
      get '/initialize_session'
      assert cookies['next_key'].present?, 'create new session'
      assert_nil cookies['destroy'], 'have no destroy cookie'
      assert cookies['first_key'].present?, 'have the source session'
      get '/session_id'
      assert cookies['first_key'].present?, 'have the source session'
      get '/get', key: 'fuga'
      assert_equal body, 'session_value!!!'
    end
  end

  def test_having_both_session
    first_cookie, second_cookie = nil, nil
    second_session_id = nil
    with_test_route_set(ActionDispatch::Session::CookieStore, key: 'key') do
      get '/store', key: 'fuga', value: 'value1'
      first_cookie = cookies['key']
    end
    with_test_route_set(ActionDispatch::Session::CookieStore, key: 'key') do
      get '/store', key: 'fuga', value: 'value2'
      second_cookie = cookies['key']
      get '/session_id'
      second_session_id = body
    end
    with_test_route_set(ActionDispatch::Session::CookieStoreForMigration, key: 'next_key', source_session_store: {
      session_store: ActionDispatch::Session::CookieStore,
      options: {
        key: 'first_key'
      },
      destroy: 'destroy'
    }) do
      cookies['first_key'] = first_cookie
      cookies['next_key'] = second_cookie
      get '/session_id'
      assert_equal second_session_id, body
      assert_nil cookies['destroy']
      get '/get', key: 'fuga'
      assert_equal 'value2', body
      assert_nil cookies['destroy']
    end
  end

  def test_without_source_session
    no_session_store = double
    with_test_route_set(ActionDispatch::Session::CookieStoreForMigration, key: 'key', source_session_store: {
      session_store: no_session_store,
      options: {
        key: 'no_key'
      },
      destroy: 'destroy'
    }) do
      get '/session_id'
      assert_equal body, '' # there are no session
      assert_nil cookies['destroy']
      expect(no_session_store).to_not receive(:new)
      get '/initialize_session'
      get '/session_id'
      assert body.present? # there are no session
    end
  end

  private
  def get(path, parameters = nil, env = {})
    env["action_dispatch.key_generator"] ||= Generator
    super
  end

  def with_test_route_set(session_store, options = {})
    with_routing do |set|
      set.draw do
        get ':action', :to => ::CookieStoreForMigrationTest::SessionController
      end
      @app = self.class.build_app(set) do |middleware|
        middleware.use session_store, options
      end
      yield
    end
  end
end
