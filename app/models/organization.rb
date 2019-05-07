require 'elasticsearch/persistence/model'

class Organization
	
	include Elasticsearch::Persistence::Model

	index_name "pathofast-organizations"

	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	DEFAULT_LOGO_URL = "/assets/default_logo.svg"

	attribute :name, String, mapping: {type: 'keyword'}

	attribute :address, String, mapping: {type: 'keyword'}
	
	attribute :phone_number, String, mapping: {type: 'keyword'}

	attribute :description, String, mapping: {type: 'keyword'}

	attribute :user_ids, Array, mapping: {type: 'keyword'}, default: []

	attribute :rejected_user_ids, Array, mapping: {type: 'keyword'}, default: []

	## how many users are necessary to verify any change in a document that
	## includes the versioned Concern.
	attribute :verifiers, Integer, mapping: {type: 'integer'}, default: 2

	## the different roles that can be there in this organizations.
	## basically searches the public tags or the tags of this organization
	attribute :role_ids, Array, mapping: {type: 'keyword'}

	## loaded from role_ids.
	attr_accessor :employee_roles

	attr_accessor :role_name


	attr_accessor :users_pending_approval
	attr_accessor :verified_users
	attr_accessor :rejected_users


	validates_presence_of :address

	validates_presence_of :phone_number

	## so there have to be some roles.
	## let me make the ui to accept a role.
	## can i launch a modal ?
	## on show organization.
	## with a link with the role.
	## so user has to have something called an organization_role_id.
	## max types of employees in an organization can be 10.
	#validates_length_of :role_ids, :minimum => 1, :maximum => 10
	## so this means you have to make some roles while creating the organization.
	## so lets start with that
	## before that get tags working.

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
	      
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		    indexes :address, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		    indexes :phone_number, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		end

	end	

	before_save do |document|
		document.public = Concerns::OwnersConcern::IS_PUBLIC
		document.assign_employee_roles
	end

	after_find do |document|
		document.load_users_pending_approval
		document.load_verified_users
		document.load_rejected_users
		document.load_employee_roles
	end

	## so these are the permitted params.
	def self.permitted_params
		[:id,{:organization => [:name, :description, :address,:phone_number, {:user_ids => []}, :role_name,  {:role_ids => []}, {:rejected_user_ids => []}] }]
	end

	############################################################
	##
	##
	## CALLBACK METHODS.
	##
	##
	############################################################
	def load_users_pending_approval
		result = User.es.search({
			body: {
				query: {
					bool: {
						must: [
							{
								term: {
									organization_id: self.id.to_s
								}
							}
						],
						must_not: [
							{
								ids: {
									values: self.user_ids
								}
							}
						]
					}
				}
			}
		})

		#puts result.results.to_s

		#puts "came to after find to set the users pending approval."
		self.users_pending_approval ||= []
		result.results.each do |res|
			puts "the user pending approval is: #{res}"
			self.users_pending_approval << res
		end

	end

	def load_verified_users
		self.verified_users = []
		self.user_ids.each do |uid|
			self.verified_users << User.find(uid)
		end
	end

	def load_rejected_users
		self.rejected_users = []
		self.rejected_user_ids.each do |ruid|

			self.rejected_users << User.find(ruid)

		end
	end

	def load_employee_roles
		self.employee_roles ||= []
		self.role_ids.each do |rid|
			self.employee_roles << Tag.find(rid)
		end
	end	
	
	def assign_employee_roles
		if self.role_ids.blank?
			self.role_ids = []
			request = Tag.search({
				size: 10,
				query: {
					bool: {
						must: [
							{
								term: {
									tag_type: Tag::EMPLOYEE_TAG
								}
							}
						]
					}
				}
			})	
			request.response.hits.hits.each do |hit|
				self.role_ids << hit["_id"]
			end	
		end
	end
	############################################################
	##
	##
	## OVERRIDDEN from ALERT_CONCERN
	##
	##
	############################################################
	def set_alert
		## how do we delete it.
		self.alert = ""
		if self.images.blank?
			self.alert += "1.You are using the default logo, please upload an image of your own logo"
		end
		if self.role_ids.blank?
			self.alert += "2. Please add some employee roles by visiting TAGS, these will be added to your organization."
		end
	end

	## dob is not working in profiles page
	## 

end