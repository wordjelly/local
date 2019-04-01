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

	attr_accessor :statuses

	attr_accessor :reports

	def set_id_from_barcode
		self.id = self.barcode unless self.barcode.blank?
	end

	before_save do |document|
		document.name = document.barcode
		document.set_id_from_barcode
	end

	after_find do |document|
		res = document.get_statuses
		document.statuses = res[:statuses]
		document.reports = res[:reports]
	end

	## we have to have only one 
	## does it go by report ?
	## we should be able to sort somehwo.
	## there may be 100 reports
	## that are delayed.
	## 200
	## just from 10 patients.
	## so the first thing to do is to filter by order.
	## can we somehow deduplicate at the order level.
	## 
	
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

	def get_statuses
		search_results = Order.search({
			_source: false,
			query: {
				nested: {
					path: "tubes",
					query: {
						term: {
							"tubes.barcode".to_sym => {
								value: self.id.to_s
							}
						}
					},
					inner_hits: {}
				}
			}
		})
		patient_report_ids = []
		unless search_results.response.hits.hits.blank?
			search_results.response.hits.hits.each do |outer_hit|
				outer_hit.inner_hits.tubes.hits.hits.each do |hit|
					patient_report_ids = hit._source.patient_report_ids
				end
			end
		end	
		
		## so here we send this as the query.
		Status.gather_statuses({
			ids: {
				values: patient_report_ids
			}
		})

	end


	def update_status(template_status_id)

	end



end