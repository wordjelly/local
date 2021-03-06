Auth.configure do |config|

	config.mount_path = "/authenticate"
		
	## get this working with the api.
	## for authentication.
	## then move to 

	config.auth_resources = {
    	"User" => {
	    	:nav_bar => true,
	    	:login_params => [:email,:additional_login_param],
	    	:additional_login_param_name => "mobile",
	      	:additional_login_param_resend_confirmation_message => "Resend OTP",
	      	:additional_login_param_new_otp_partial => "auth/modals/new_otp_input.html.erb",
	      	:additional_login_param_resend_confirmation_message_partial => "auth/modals/resend_otp.html.erb",
	      	:additional_login_param_verification_result_partial => "auth/modals/verify_otp.html.erb"
	    }
	}

  	config.otp_controller = "otp"
  	config.navbar = true
  	config.brand_name = "PathoFast"
  	config.enable_sign_in_modals = true
  	config.recaptcha = false
  	config.enable_token_auth = true

  	config.third_party_api_keys = {
    	:two_factor_sms_api_key => ENV["TWO_FACTOR_SMS_API_KEY"] 
  	}

	config.host_name = ENV["HOST_NAME"]
	config.mailer_class = "PathofastMailer"
	## => google oauth details
	## app : jmaps-1/OAuth 2.0 client IDs/pathofast
	## account : bhargav.r.raut
	  
	## => facebook oauth details
	## app : pathofast
	## account : bhargav's facebook.
	config.oauth_credentials = {
	    "google_oauth2" => {
	      	"app_id" => ENV["GOOGLE_APP_ID"],
	      	"app_secret" => ENV["GOOGLE_APP_SECRET"],
	      	"options" => {
	        	:scope => "email, profile",
	            	:prompt => "select_account",
	            	:image_aspect_ratio => "square",
	            	:image_size => 50
	      	}
	    },
	    "facebook" => {
	      	"app_id" => ENV["FACEBOOK_APP_ID"],
	      	"app_secret" => ENV["FACEBOOK_APP_SECRET"],
	      	"options" => {
	        	:scope => 'email',
	        	:info_fields => 'first_name,last_name,email,work',
	        	:display => 'page'
	      	}
	    }
	}


	config.profiles_controller = "profiles"
	
	########################################################
	##
	##
	## MONGOID ELASTICSEARCH CLIENT CONFIGURATION.
	## THIS CLIENT WILL FUNCTION DIFFERENTLY FROM THE
	## ES CLIENT CONFIGURED FOR THE REST OF THE APP.
	##
	##
	########################################################
	es_port = ENV["LOCAL_ES_PORT"]
	if Rails.env.production?
	  es_user = ENV["REMOTE_ES_USER"] 
	  es_password = ENV["REMOTE_ES_PASSWORD"]
	  host = {host: ENV["REMOTE_ES_HOST"], scheme: 'https', port: ENV["REMOTE_ES_PORT"]}
	  host.merge!({user: es_user, password: es_password})
	  es_port = ENV["REMOTE_ES_PORT"]
	else
	  host = {host: 'localhost', scheme: 'http', port: es_port}
	end

	Mongoid::Elasticsearch.prefix = Auth.configuration.brand_name.downcase + "_"

	Mongoid::Elasticsearch.client_options = {hosts: [host], port: es_port, transport_options: {headers: {"Content-Type" => "application/json" }, request: { timeout: 45 }}}



end

SimpleTokenAuthentication.configure do |config|

	config.permissions = $permissions

end