# CookieStoreForMigration

別のセッションストア(memcacheなど)からCookieセッションストアに移行する際、セッション情報(ログイン情報等)が消えないようにするためのセッションストア。

## 設定
`config/initializer/session_store.rb`にて``:cookie_store_for_migration`をセッションストアとして利用するようにする。

例:
```ruby
RailsApp::Application.config.session_store :cookie_store_for_migration,
                                           key: 'new_session_key',
                                           domain: 'example.com',
                                           source_session_store: {
                                             session_store: :mem_cache_store,
                                             options: {
                                               memcache_server: '127.0.0.1:11211',
                                               key: 'old_session_key',
                                               namespace: "rails_app-#{Rails.env}",
                                               domain: 'example.com'
                                             },
                                             destroy: 'destroy_old_session'
                                           }
```

設定項目は`CookieStore`のものの他に`:source_sessoin_store`オプションを用いる。

`:source_session_store`の項目はそれぞれ次のような意味を持つ。
 * `:session_store`
  * 移行元のセッションストア。HashかClassを指定する。
 * `:options`
  * 移行元のセッションストアのオプション。
 * `:destroy`
  * 移行元のセッションストアの情報を破棄する時に利用するCookieのKeyの名前を表す文字列。指定しない場合は移行元のセッションストアの情報やセッションキーは破棄されない。
