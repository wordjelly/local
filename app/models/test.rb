require 'elasticsearch/persistence/model'

class Test	
	
	include Elasticsearch::Persistence::Model
	
	attribute :name, String

=begin
	attribute :lis_code, String, mapping: { 
				:type => 'keyword', 
				:fields => {
			        :raw => { 
			          	:type =>  'text', 
						:analyzer => "nGram_analyzer",
						:search_analyzer => "whitespace"
			        }
			    }
			}
=end	
	attribute :price, Float
	
=begin
	attribute :description, String, mapping: {type: 'text', analyzer: "nGram_analyzer", search_analyzer: "whitespace"}
=end
	attribute :patient_id, String
	
	attribute :result, Float
	
	attribute :email_status, String
	
	attribute :sms_status, String
	
	attribute :status, String
	
	attribute :normal_ranges ,Array[Hash]

	attribute :report_id, String

	attribute :tube_ids, Array

	## who all to notify at every status change.
	attribute :emails, Array

	## which mobile numbers to notify at every status change.
	attribute :mobile_numbers, Array

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
	      		:analyzer => "standard"
	      	}
	      }
	    end
	end


	# so so much for the search part.
	# will have to configure it tomorrow.
	

=begin
	 do
	    mappings dynamic: 'false',
	      	analysis:  {
	            filter:  {
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
        	} do 

	    end
	end
=end
	


	## what methods will be necessary
	## given a tube id and a lis code, update it.
	def self.lis_update(lis_code, tube_id)
		
	end

	def verify

	end

	def notify

	end

	## print is available on the report only.

end