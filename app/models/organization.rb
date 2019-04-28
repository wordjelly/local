require 'elasticsearch/persistence/model'

class Organization
	
	include Elasticsearch::Persistence::Model

	index_name "pathofast-organizations"

	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern

	DEFAULT_LOGO_URL = "/assets/default_logo.svg"

	attribute :name, String, mapping: {type: 'keyword'}

	attribute :address, String, mapping: {type: 'keyword'}
	
	attribute :phone_number, String, mapping: {type: 'keyword'}

	attribute :description, String, mapping: {type: 'keyword'}

	attribute :user_ids, Array, mapping: {type: 'keyword'}, default: []

	attribute :rejected_user_ids, Array, mapping: {type: 'keyword'}, default: []

	attr_accessor :users_pending_approval

	validates_presence_of :address

	validates_presence_of :phone_number


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



	after_find do |document|
		# show those users who are not yet approved for 
		# this organization.
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

		puts result.results.to_s

		puts "came to after find to set the users pending approval."

		document.users_pending_approval ||= []
		result.results.each do |res|
			puts "the user pending approval is: #{res}"
			document.users_pending_approval << res
		end

		#document.users_pending_approval ||= result.results
		#document.users_pending_approval ||= []

	end

	## so these are the permitted params.
	def self.permitted_params
		[:id,{:organization => [:name, :description, :address,:phone_number, {:user_ids => []}, {:rejected_user_ids => []}] }]
	end

	############################################################
	##
	##
	## OVERRIDDEN from ALERT_CONCERN
	##
	##
	############################################################
	def set_alert
		if organization.logo_url == Organization::DEFAULT_LOGO_URL
			self.alert = "You are using the default logo, please upload an image of your own logo"
		end
	end

end