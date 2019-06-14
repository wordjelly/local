require 'elasticsearch/persistence/model'
class ItemRequirement 
	
	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern

	index_name "pathofast-item-requirements"


	attribute :name, String, mapping: {type: "keyword"}
	validates_presence_of :name
	## so let's say its item type remains constant at 
	## serum_tube
	## but then let's say that we create this requirement 
	## the amounts will have to be defined based on the test
	## so amount will be a hash.
	## so item type will be serum
	## name will be golden_top_tube.
	## and amounts will be hashified.
	## then that will have to be modified load time.
	## we cannot create two item_requirements with the same name
	## we also cannot create two item_types with the same name
	## so we have to make the id the name.
	attribute :item_type, String, mapping: {type: "keyword"}
	validates_presence_of :item_type
	
	attribute :definitions, Array[Hash]

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

		    indexes :definitions, type: 'nested', properties: {
		    	report_id: {
					type: "keyword"
				},
				report_name: {
					type: "keyword"
				},
				amount: {
					type: "float"
				},
				priority: {
					type: "integer"
				}
		    }

	    end
	end

	def load_associated_reports
		puts "loaded associated reports"
		self.associated_reports = []
	end

	## what if this is more than 100?
	## so from a given tube it can remove how much?
	## 
	def get_amount_for_report(report_id)
		puts " --------- came to get amount for report ------- "
		puts self.definitions.to_s
		defs = self.definitions.select{|c|
			c["report_id"] == report_id
		}
		(defs[0]["amount"] > 100) ? 100 : defs[0]["amount"]
	end

	## suppose we have the item requirements
	## inside the tests
	## no need for any seperate item requirements.
	## so that's one model less
	## ?
	## i can do that.
	## inside test itself.

end