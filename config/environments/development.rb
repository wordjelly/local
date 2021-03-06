Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.action_controller.asset_host = 'http://localhost:3000'
  config.action_mailer.asset_host = config.action_controller.asset_host

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  ## Local MailServer Configuration : eg. for Mailcatcher
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  
  config.action_mailer.logger = nil
  
  #config.action_mailer.delivery_method = :smtp
  #config.action_mailer.smtp_settings = {:address => "localhost", :port => 1025}

  ### Mailgun configuration.
  
  config.action_mailer.delivery_method = :mailgun
  config.action_mailer.mailgun_settings = {
    api_key: ENV["MAILGUN_API_KEY"],
    #domain: 'sandboxc0248205473845c3a998e44941ee503e.mailgun.org'
    domain: 'pathofast.com'
  }

  ## NOTIFICATION(TRANSACTIONAL AFTER REPORT GENERATION, AND PDF JOBS)
  config.ignore_pdf_job = false

  config.ignore_notification_job = true
  
  config.ignore_trigger_lis_job = true
  
end
