require 'elasticsearch/persistence/model'
class Status

	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern

	index_name "pathofast-statuses"

	attribute :name, String
	attribute :report_id, String
	attribute :item_id, String
	attribute :item_group_id, String
	attribute :order_id, String
	attribute :response, Boolean

	## will call a method named "on_#{name}" after create on 
	## each object who can be resolved, in a background job.
	## so if status is verified
	## will call on_verified , on report, item, item_group, and order
	## if the method does not exist, won't do anything
	## will store the results of calling that method, on the object
	## if the object wants to call that method again, it has to set that status again.
	## if it has to be retried.
	## if the job fails, the status gets marked as failed.
	## and will give the reason for it.

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
		end

	end

	## if the report status is "verified -> certain actions cna be done"
	## and the status will track the notifications.

end