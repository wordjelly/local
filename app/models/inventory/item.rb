require 'elasticsearch/persistence/model'

class Inventory::Item

	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-inventory-items"
	document_type "inventory/item"

	## so the root of everything is the item type.
	attribute :item_type_id, String, mapping: {type: 'keyword'}
	validates_presence_of :item_type_id

	attribute :transaction_id, String, mapping: {type: 'keyword'}
	validates_presence_of :transaction_id

	attribute :name, String, mapping: {type: 'keyword'}

	attribute :location_id, String, mapping: {type: 'keyword'}

	attribute :filled_amount, Float

	attribute :expiry_date, DateTime
	validates_presence_of :expiry_date

	attribute :barcode, String
	validates_presence_of :barcode

	attribute :contents_expiry_date, DateTime	

	attr_accessor :statuses

	attr_accessor :reports

	#def set_id_from_barcode
	#	self.id = self.barcode unless self.barcode.blank?
	#end

	## so we did barcode uniqueness
	## now we have to go for 

	after_find do |document|
		res = document.get_statuses
		document.statuses = res[:statuses]
		document.reports = res[:reports]
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
	########################################################
	##
	##
	## METHOD OVERRIDEN FROM NAMEIDCONCERN
	##
	##
	########################################################
	def assign_id_from_name
		## so this is done
		## make an item and item group controller.
		## and views
		## then we move to item transfer.
		if self.id.blank?			
			self.id = self.name = self.barcode
		end
	end

end