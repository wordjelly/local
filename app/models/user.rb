require 'elasticsearch/persistence/model'

class User

	include Elasticsearch::Persistence::Model

	index_name "pathofast-users"

	attribute :first_name, String

	attribute :last_name, String

	attribute :email, String

	attribute :mobile_number, String, mapping: {type: "keyword"}

	attribute :password, String, mapping: {type: "keyword"}

	attribute :password_confirmation, String, mapping: {type: "keyword"}

	attribute :forgot_password_token, String, mapping: {type: "keyword"}

	attribute :date_of_birth, DateTime

	attribute :area, String

	attribute :group, String, mapping: {type: 'keyword'}

	attribute :otp, String, mapping: {type: 'keyword'}

	attribute :organization_ids, Array, mapping: {type: 'keyword'}

	attr_accessor :skip_background_job

	##########################################################
	##
	##
	## after_save , which background job action to trigger?
	##
	##
	##########################################################

	attribute :resend_otp, Integer, :default => 0

	attribute :forgot_password, Integer, :default => 0

	before_save do |document|
		document.id = document.mobile_number if document.id.blank?
		document.organization_ids << document.id if document.organization_ids.blank?
	end

	after_save do |document|
		if document.skip_background_job.blank?
			ScheduleJob.perform_later([document.id.to_s,document.class.name])
		end
	end

	def compare_and_refresh_access_token(access_token)
		if self.access_token == access_token
			if self.token_expires_at <= Time.now
				self.refresh_tokens
			end
			self.access_token
		else
			nil
		end
	end

	## the background job.
	## problem is that it will still show that 
	## stuff like resend otp/
	## so if on find, we reset that.
	def schedule
		if self.uuid.blank?
			self.sign_up
		end
		if !self.otp.blank?
			if self.mobile_confirmed == 0
				self.confirm_otp
			end
		end
		if self.resend_otp == 1
			## should reset resend otp.
			self.do_resend_otp
		end
		if self.forgot_password == 1
			## should resent forgot_password.
			self.do_forgot_password
		end
		## and sign in, is done in the controller itself ?
		## or when ?
		## is that a save call ?
	end

	##########################################################3
	##
	##
	## INTERNALLY USED BY COGNITO
	##
	##
	###########################################################

	attribute :mobile_confirmed, Integer, :default => 0

	attribute :mobile_confirmation_attempt_time, Date

	attribute :email_confirmed, Integer, :default => 0

	attribute :email_confirmation_attempt_time, Date

	attribute :uuid, String

	attribute :access_token, String, mapping: {type: "keyword", ignore_above: 5000}

	attribute :refresh_token, String, mapping: {type: "keyword", ignore_above: 5000}

	attribute :token_expires_at, Date

	attribute :id_token, String, mapping: {type: "keyword", ignore_above: 10000}

	attribute :cognito_username, String, mapping: {type: "keyword", ignore_above: 1000}

	############################################################
	##
	##
	## END
	##
	##
	############################################################


	settings index: { 
	    number_of_shards: 1, 
	    number_of_replicas: 0,
	    analysis: {
		      	filter: {
			      	nGram_filter:  {
		                type: "nGram",
		                min_gram: 2,
		                max_gram: 20,
		               	token_chars: [
		                   "letter",
		                   "digit",
		                   "punctuation",
		                   "symbol"
		                ]
			        }
		      	},
	            analyzer:  {
	                nGram_analyzer:  {
	                    type: "custom",
	                    tokenizer:  "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding",
	                        "nGram_filter"
	                    ]
	                },
	                whitespace_analyzer: {
	                    type: "custom",
	                    tokenizer: "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding"
	                    ]
	                }
	            }
	    	}
	  	} do

	    mapping do
	      
		    indexes :first_name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		    indexes :last_name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		end

	end

	def name
		self.first_name + " " + self.last_name
	end

	def age
		return nil unless self.date_of_birth
		now = Time.now.utc.to_date
  		now.year - date_of_birth.year - ((now.month > date_of_birth.month || (now.month == date_of_birth.month && now.day >= date_of_birth.day)) ? 0 : 1)
	end

	def self.permitted_params
		[:id, :access_token ,{:user => [:email, :mobile_number, :password, :password_confirmation, :resend_otp, :forgot_password, :forgot_password_token] }]
	end

	
	def calculate_cognito_hmac
		key = ENV['COGNITO_SECRET_HASH']
		data = ((self.cognito_username) || (self.mobile_number)) + ENV['COGNITO_CLIENT_ID']
		digest = OpenSSL::Digest.new('sha256')
		hmac = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, key, data))
	end	

	def sign_up
		c = Aws::CognitoIdentityProvider::Client.new
		begin
			response = c.sign_up({
				username: self.mobile_number,
				password: self.password,
				secret_hash: calculate_cognito_hmac,
				client_id: ENV["COGNITO_CLIENT_ID"],
				user_attributes: [
					{
						name: "phone_number",
						value: self.mobile_number
					},
					{
						name: "email",
						value: self.email
					}
				]
			})
			puts "sign up response is:"
			puts response.to_s
			self.uuid = response["user_sub"]
			self.skip_background_job = true
			self.save
		rescue => e
			puts e.to_s
			puts "there was an error"
			self.errors.add(:id,e.to_s)
			self.save
		end	
	end

	## should be called immediately after sign_in.
	def set_cognito_username
		if self.cognito_username.blank?
			begin
				c = Aws::CognitoIdentityProvider::Client.new
				response = c.get_user({
					access_token: self.access_token
				})
				self.cognito_username = response.username
				self.save
			rescue => e
				self.errors.add(:id,e.to_s)
			end
		end
	end

	def confirm_otp
		begin
			c = Aws::CognitoIdentityProvider::Client.new
			response = c.confirm_sign_up({
				username: self.mobile_number,
				secret_hash: calculate_cognito_hmac,
				client_id: ENV["COGNITO_CLIENT_ID"],	
				confirmation_code: self.otp
			})
			self.mobile_confirmed = response.successful? ? 1 : 0
			self.mobile_confirmation_attempt_time = Time.now
		rescue => e
			self.errors.add(:id,e.to_s)
		end
		self.save
	end

	## @return[User]
	## first does cognito authentication.
	## if an access token is returned, searches our database for a user with this username.
	## assigns the access token to that user, as well as refresh token.
	## saves that user.
	## then adds that user to the session
	## finally returns the user.
	def sign_in
		begin
			c = Aws::CognitoIdentityProvider::Client.new
			resp = c.initiate_auth({
			  auth_flow: "USER_PASSWORD_AUTH",
			  auth_parameters: {
			    "USERNAME" => self.mobile_number,
			    "PASSWORD" => self.password,
			    "SECRET_HASH" => calculate_cognito_hmac
			  },
			  client_id: ENV["COGNITO_CLIENT_ID"]
			})
			puts "sign in response:"
			puts resp.to_s
			self.access_token = resp[:authentication_result][:access_token]
			self.refresh_token = resp[:authentication_result][:refresh_token]
			self.token_expires_at = Time.now + (resp[:authentication_result][:expires_in]).seconds
			self.id_token = resp[:authentication_result][:id_token]
			set_cognito_username
		rescue => e
			puts e.to_s
		end		
	end

	## so lets sign in , then try to refresh the tokens.
	## so when we created the user, it has to be with that id.
	## or we can search by the mobile number.
	## instead of giving it that id.

	def refresh_tokens
		begin
			c = Aws::CognitoIdentityProvider::Client.new
			resp = c.initiate_auth({
			  auth_flow: "REFRESH_TOKEN",
			  auth_parameters: {
			    "REFRESH_TOKEN" => self.refresh_token,
			    "SECRET_HASH" => calculate_cognito_hmac
			  },
			  client_id: ENV["COGNITO_CLIENT_ID"]
			})
			
			self.access_token = resp[:authentication_result][:access_token]
			self.refresh_token = resp[:authentication_result][:refresh_token]
			self.token_expires_at = Time.now + (resp[:authentication_result][:expires_in]).seconds
			self.save
			#session[:user] = self
		rescue => e
			e.to_s
		end	
	end


	def self.get_user(params)
		if session[:user]
			if session[:user].id == params[:id]
				session[:user]
			else
				session.delete(:user)
				nil
			end
		else
			search_results = User.search({
				query: {
					bool: {
						must: [
							{
								ids: {
									values: [params[:id]]
								}
							},
							{
								term: {
									access_token: params[:access_token]
								}
							}
						]
					}
				}
			})
			u = nil
			search_results.response.hits.hits.each do |hit|
				u = User.new(hit["_source"])
				if u.token_expires_at < Time.now.to_i
					u.refresh_tokens
				end
			end
			u			
		end
	end

	def pending_mobile_confirmation?
		((!self.mobile_number.blank?) && (self.mobile_confirmed == 1))
	end

	def confirmed?
		((self.mobile_confirmed == 1) || (self.email_confirmed == 1))
	end

	#############################################################
	##
	##
	## COGNITO WRAPPER METHODS
	##
	##
	#############################################################
	
end