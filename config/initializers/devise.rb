Devise::Mailer.layout "mailer"
Devise.setup do |config|
  config.scoped_views = true
  config.mailer_sender = ENV["LIS_CONTACT_EMAIL"]
end