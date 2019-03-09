require 'elasticsearch/persistence/model'

class Item

	include Elasticsearch::Persistence::Model

	include Concerns::ImageLoadConcern

	index_name "pathofast-items"

	## now comes the issue of item types.
	## locations
	## statuses
	## all these have to be added.
	## so it will autocomplete from where ?
	## call it attributes ?
	## or if we type in that field, it will autocomplete from only that collection.
	## so we have to have seperate objects for that.
	## like add new status
	## add new location
	## add new item_type

	attribute :item_type, String

	attribute :location, String

	attribute :filled_amount, Float

	attribute :expiry_date, DateTime

	attribute :barcode, String

	attribute :contents_expiry_date, DateTime	

	def set_id_from_barcode
		self.id = self.barcode unless self.barcode.blank?
	end

	before_save do |document|
		document.set_id_from_barcode
	end

	
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
	      
		    indexes :barcode, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		end

	end	


end