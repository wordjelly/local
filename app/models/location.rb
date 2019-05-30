require 'elasticsearch/persistence/model'
class Location

	include Elasticsearch::Persistence::Model

	index_name "pathofast-locations"

	attribute :name, String

	attribute :spots, Array[Hash]

	attribute :latitude, Float

	attribute :longitude, Float

	attribute :address, String, mapping: {type: 'keyword'}

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

		    indexes :spots, type: 'nested' do 
		    	indexes :tags, type: 'keyword'
		    end
		end

	end
	
	## so these are the location and sub location attributes
	## one location should be automatically created?
	## from the organization address?
	def self.permitted_params
		base = [
				:id,
				{:location => 
					[
						:name,
						:latitude,
						:longitude,	
						{
							:spots => [
								:tags
							]
						}
					]
				}
			]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		base
	end

end