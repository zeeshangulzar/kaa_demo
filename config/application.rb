require File.expand_path('../boot', __FILE__)

require 'rails/all'
require './lib/hes_security/hes_security'
require './lib/h_e_s_rescue_bad_request'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

APPLICATION_NAME = 'kaa'
APP_NAME_ENCODED = APPLICATION_NAME.underscore
IS_STAGING=false

module Go
  class Application < Rails::Application
    config.middleware.insert_after Rails::Rack::Logger, HESSecurityMiddleware
    config.middleware.insert_before ActionDispatch::ParamsParser, HESRescueBadRequest
    config.middleware.insert_before HESSecurityMiddleware, Rack::Cors do
        allow do
            origins '*'
            resource '*', :headers => :any, :methods => [:get, :post, :put, :delete]
        end
    end
    #config.middleware.insert_before ActionDispatch::Static, HESSecurityMiddleware

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib #{config.root}/lib/content #{config.root}/app/jobs )

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.plugins = [:many_to_many, :all]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.action_mailer.smtp_settings = {
      :address    =>  'email.hesonline.com',
      :port       =>  25,
      :domain     =>  'email.hesonline.com'
    }

    # set memcached server, TODO: is this the best place? No - should have a config for this, resque server, etc.
    memcached_server = 'localhost:11211'
    if Rails.env == 'production' && !IS_STAGING
      memcached_server = 'kaa.memcached.hesapps.com:11211'
    end
    config.memcached_server = memcached_server

    # memcache
    config.cache_store = :dalli_store, Rails.application.config.memcached_server, {:compress => true, :namespace => APPLICATION_NAME, :expires_in => 1.day}
  end
end
