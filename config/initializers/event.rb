require "resolv-replace"
require "rest-firebase"
require "typhoeus"
require "active_support/all"
require "jwt"
require "net/http"

RestFirebase.class_eval do 
	
	attr_accessor :private_key_hash

	def query
    	{:access_token => auth}
  	end

  	def get_jwt
		puts Base64.encode64(JSON.generate(self.private_key_hash))
		# Get your service account's email address and private key from the JSON key file
		$service_account_email = self.private_key_hash["client_email"]
		$private_key = OpenSSL::PKey::RSA.new self.private_key_hash["private_key"]
		  now_seconds = Time.now.to_i
		  payload = {:iss => $service_account_email,
		             :sub => $service_account_email,
		             :aud => self.private_key_hash["token_uri"],
		             :iat => now_seconds,
		             :exp => now_seconds + 1, # Maximum expiration time is one hour
		             :scope => 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/firebase.database'

		         }
		  JWT.encode payload, $private_key, "RS256"
		
	end

	def generate_access_token
	  uri = URI.parse(self.private_key_hash["token_uri"])
	  https = Net::HTTP.new(uri.host, uri.port)
	  https.use_ssl = true
	  req = Net::HTTP::Post.new(uri.path)
	  req['Cache-Control'] = "no-store"
	  req.set_form_data({
	    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
	    assertion: get_jwt
	  })

	  resp = JSON.parse(https.request(req).body)
	  resp["access_token"]
	end

	def generate_auth opts={}
		generate_access_token
	end
 
end

class Event

	include StreamModule

	def initialize(private_key_hash)
		self.private_key_hash = private_key_hash
		self.event_source = "dummy"
		setup_connection
	end

	## so we will delete all the orders and see what happens.
	## @param[String] organization_id : the id of the organization
	## @param[Hash] data : the data hash.
	def trigger_lis_poll(organization_id,data)
		puts self.connection.put("organizations/#{organization_id}/trigger_lis_poll",data)
		Rails.logger.info("Notifying organization: #{organization_id}, to poll lis")
	end

	def trigger_order_delete(organization_id,data)
		self.connection.put("organizations/#{organization_id}/delete_order",data)
		Rails.logger.info("Notifying organization: #{organization_id}, to delete order:#{data}")
	end

end

## global class is here as well.
private_key_hash = JSON.parse(IO.read(Rails.root.join("config","firebase_credentials.json")))
$event_notifier = Event.new(private_key_hash)