require 'elasticsearch/persistence/model'
class Patient

	include Elasticsearch::Persistence::Model

	index_name "pathofast-patients"

	attribute :first_name, String

	attribute :last_name, String

	attribute :email, String

	attribute :mobile_number, String

	attribute :date_of_birth, DateTime

	attribute :area, String

	attribute :allergies, String

	attribute :anticoagulants, String

	attribute :diabetic, String

	attribute :asthmatic, String

	attribute :heart_problems, String

	attribute :sex, String
	##########################################
	##
	##
	## UTILITY METHODS USED IN VIEWS.
	##
	##
	##########################################

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

	def alert_information
		alert = ""
		alert += " allergic," if self.allergies == 1
		alert += " on blood thinners," if self.anticoagulants == 1
		alert += " a diabetic," if self.diabetic == 1
		alert += " an asthmatic," if self.asthmatic == 1
		alert += " has heart problems" if self.heart_problems == 1
		return alert if alert.blank?
		return "The patient" + alert
	end

end