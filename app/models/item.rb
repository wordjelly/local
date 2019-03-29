require 'elasticsearch/persistence/model'

class Item

	include Elasticsearch::Persistence::Model

	include Concerns::ImageLoadConcern

	include Concerns::StatusConcern

	index_name "pathofast-items"

	attribute :item_type, String
	validates_presence_of :item_type

	attribute :name, String

	attribute :location, String

	attribute :filled_amount, Float

	attribute :expiry_date, DateTime
	validates_presence_of :expiry_date

	attribute :barcode, String
	validates_presence_of :barcode

	attribute :contents_expiry_date, DateTime	

	def set_id_from_barcode
		self.id = self.barcode unless self.barcode.blank?
	end

	before_save do |document|
		document.name = document.barcode
		document.set_id_from_barcode
	end

	after_find do |document|
		document.gather_statuses
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
	      
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		end

	end	

	## 12 hourly.

	## if i can finish status views tomorrow(overall, order, report, patient, item)
	## with equipment links for report updates

	## then i can try to do user authorization on sunday(cognito),
	## together with jobs
	
	## polish off in one week more.
	
	## one more week, for remaining interfacing and controls 
	## data.
	## + integration with app. 

end