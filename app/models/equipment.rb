require 'elasticsearch/persistence/model'

class Equipment

	## lets rename this to machine.
	## it cannot be equipment number.
	## that is a specific to a particular lab
	## it has to be an equipment type.
	## equipment type also comes from tags.
	## or registered equipment names?
	## we can search public equipment names.
	include Elasticsearch::Persistence::Model

	include Concerns::ImageLoadConcern

	include Concerns::StatusConcern

	index_name "pathofast-equipment"

	attribute :name, String, mapping: {type: 'keyword'}
	validates_presence_of :name

	attribute :definitions, Array[Hash]


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

		    indexes :definitions, type: 'nested', properties: {
		    	report_id: {
					type: "keyword"
				},
				report_name: {
					type: "keyword"
				},
				priority: {
					type: "integer"
				}
		    }

	    end
	    
	end

	## so make an equipments controller and get it working like 
	## item requirements.

end