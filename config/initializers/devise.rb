Devise::Mailer.layout "mailer"
Devise.setup do |config|
  config.scoped_views = true
end