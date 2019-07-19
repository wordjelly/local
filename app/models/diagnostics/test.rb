require 'elasticsearch/persistence/model'
class Diagnostics::Test	
	
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
		
	index_name "pathofast-tests"

	## mapped in block
	attribute :name, String

	## mapped in block
	attribute :lis_code, String

	## mapped in block
	attribute :description, String

	## references
	attribute :references, Array, mapping: {type: 'keyword'}, default: []

	attribute :ranges, Array[Diagnostics::Range], mapping: {type: 'keyword'}

=begin
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

	      	indexes :lis_code, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :description, type: 'text'

	    end

	end
=end
=begin
	def self.permitted_params
		[:id , {:test => [:name,:lis_code,:description,:price]}]
	end
=end
	
	def self.permitted_params

		[
			:name,
			:lis_code,
			:description,
			:verified,
			{:references => []},
			:machine,
			:kit,
			{
				:ranges => Diagnostics::Range.permitted_params
			}
		]

	end

	def self.index_properties
		{
	    	name: {
	    		type: 'keyword',
	    		fields: {
	    			:raw => {
	    				:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
	    			}
		    		}
	    	},
	    	lis_code: {
	    		type: 'keyword'
	    	},
	    	description: {
	    		type: 'keyword',
	    		fields: {
	    			:raw => {
	    				:type => "text"
	    			}
	    		}
	    	},
	    	verified: {
	    		type: 'boolean'
	    	},
	    	references: {
	    		type: 'keyword'
	    	},
	    	machine: {
	    		type: 'keyword'
	    	},
	    	kit: {
	    		type: 'keyword'
	    	},
	    	ranges: {
	    		type: 'nested',
	    		properties: Diagnostics::Range.index_properties
	    	}
	    }	
	end

end