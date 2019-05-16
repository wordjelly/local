require 'elasticsearch/persistence/model'

class Inventory::Item

	include Elasticsearch::Persistence::Model
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-inventory-items"
	document_type "inventory/item"	

	## its gonna be called barcode
	## and the index name is going to be 
	## is there no other way?
	## 
	## anything with a barcode has to have this in place.
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

	attr_accessor :item_group_id

	## what if the barcode of an item_group is the same as an item
	## or a transaction?
	## anything that has a barcode is going to have to share
	## the same index.
	## and a common index name.
	## add a barcode concern.
	## define the index there.
	## otherwise we are fucked.
	## we have to have methods 	to add items to groups.
	## and remove items from groups.
	after_find do |document|
		document.load_statuses_and_reports
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

	def load_statuses_and_reports
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
		res = Status.gather_statuses({
			ids: {
				values: patient_report_ids
			}
		})

		self.statuses = res[:statuses]
		self.reports = res[:reports]
	end

	def update_status(template_status_id)

	end

	########################################################
	##
	##
	## permitted params.
	##
	##
	########################################################
	def self.permitted_params
		base = [:id,{:item => [:item_type_id, :location_id, :transaction_id, :filled_amount, :expiry_date, :barcode, :contents_expiry_date]}]
		if defined? @permitted_params
			base[1][:item] << @permitted_params
			base[1][:item].flatten!
		end
		#puts "the base becomes:"
		#puts base.to_s
		base
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