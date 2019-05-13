require 'elasticsearch/persistence/model'
class Inventory::ItemType

	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern

	index_name "pathofast-inventory-item-types"
	document_type "inventory/item-type"

	attribute :name, String
	validates_presence_of :name

	BARCODE_REQUIRED = "yes"
	BARCODE_NOT_REQUIRED = "no"
	BARCODE_OPTIONS = [BARCODE_REQUIRED,BARCODE_NOT_REQUIRED]
	DEFAULT_VIRTUAL_UNITS = 1

	attribute :barcode_required, String, :default => BARCODE_NOT_REQUIRED, mapping: {type: 'keyword'}

	attribute :virtual_units, Float, :default => DEFAULT_VIRTUAL_UNITS

	## these are organization ids.
	attribute :supplier_ids, Array, mapping: {type: 'keyword'}
	attr_accessor :supplier_name
	attr_accessor :suppliers

	attribute :manufacturer_name, String, mapping: {type: 'keyword'}

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
	      
		    indexes :name,
		     	type: 'keyword',
		     	fields: {
			      	:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
			      	}
		    	},
		    	copy_to: '_all'
		end

	end

	## so we have included versioning into this also.
	## now we go forward and get it to create.
	## versioning UI also I want to complete today itself.
	def self.permitted_params
		base = [:id,{:item_type => [:name, :barcode_required, :virtual_units, :manufacturer_name,{ :supplier_ids => []}]}]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		#puts "the base becomes:"
		#puts base.to_s
		base
	end

	after_find do |document|
		document.load_suppliers
	end	
	#######################################################
	##
	##
	## CALLBACKS
	##
	##
	#######################################################
	def load_suppliers
		unless self.supplier_ids.blank?
			self.suppliers = self.suppliers_ids.map{|c|
				Organization.find(c)
			}
		end
	end

end