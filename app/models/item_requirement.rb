require 'elasticsearch/persistence/model'
class ItemRequirement 
	
	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern

	index_name "pathofast-item-requirements"

	attribute :name, String

	attribute :item_type, String
	
	attribute :optional, String
	
	attribute :amount, Float
	
	attribute :priority, Integer

	attr_accessor :associated_reports

	## this may be a part of many reports.
	## but if report id is set on it, then it is to be giving an option 
	## to remove that report.
	## so first let me add that to the options.
	## then i can finish it.
	attr_accessor :report_id

		
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

	def load_associated_reports
		puts "loaded associated reports"
		self.associated_reports = []
	end

end