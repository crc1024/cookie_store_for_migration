module ActionDispatch
  module Session
    class CookieStoreForMigration < ActionDispatch::Session::CookieStore
      ENV_SESSION_KEY = Rack::Session::Abstract::ENV_SESSION_KEY
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY

      def initialize(app, options = {})
        super app, options

        source_options = @default_options.delete(:source_session_store)
        @source_store = source_options[:session_store]
        if @source_store.is_a?(Symbol)
          @source_store = Session.const_get(@source_store.to_s.classify)
        end
        @source_options = source_options[:options]
        @destroy_source_session = source_options[:destroy]
      end

      def context(env)
        status, headers, body = super(env)

        options = env[ENV_SESSION_OPTIONS_KEY]

        if @destroy_source_session && options[:alternative_store]
          Rack::Utils.set_cookie_header!(
            headers,
            @destroy_source_session,
            @default_options.merge(value: 1, http_only: true)
          )
        end

        if options[:destroy_source_session]
          store = @source_store.new(
            ->(_env) { [0, {}, []] },
            @source_options.merge(drop: true)
          )
          store.call(duplicate_env_without_session(env))

          Rack::Utils.delete_cookie_header!(
            headers,
            @destroy_source_session,
            @default_options
          )
          Rack::Utils.delete_cookie_header!(
            headers,
            store.key,
            store.default_options
          )
        end
        [status, headers, body]
      end

      def load_session(env)
        options = env[ENV_SESSION_OPTIONS_KEY]
        if options[:alternative_store]
          env_dup = duplicate_env_without_session(env)
          store = @source_store.new(nil, @source_options)
          store.send(:prepare_session, env_dup)
          store.send(:load_session, env_dup)
        else
          super env
        end
      end

      private

      def prepare_session(env)
        super env
        options = env[ENV_SESSION_OPTIONS_KEY]
        cookies = Rack::Request.new(env).cookies

        options[:alternative_store] = !cookies.key?(key) && cookies.key?(@source_options[:key])
        options[:destroy_source_session] = @destroy_source_session &&
                                           cookies.key?(@destroy_source_session)
      end

      def extract_session_id(env)
        sid = super env
        options = env[ENV_SESSION_OPTIONS_KEY]
        if options[:alternative_store]
          env_dup = duplicate_env_without_session(env)
          store = @source_store.new(nil, @source_options)
          store.send(:prepare_session, env_dup)
          sid = store.send(:extract_session_id, env_dup)
        end
        sid
      end

      def duplicate_env_without_session(env)
        env.dup.tap do |env_dup|
          env_dup.delete(ENV_SESSION_KEY)
          env_dup.delete(ENV_SESSION_OPTIONS_KEY)
        end
      end
    end
  end
end
