require 'elasticsearch/persistence/model'

class Inventory::Item

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	
	index_name "pathofast-inventory-items"
	document_type "inventory/item"	

	## its gonna be called barcode
	## and the index name is going to be 
	## is there no other way?
	## 
	## anything with a barcode has to have this in place.
	## so the root of everything is the item type.
	## the item type needs to be internal?
	## so we have supplier item types and 
	## what about the local item types?
	## this will be the same.
	## it is not cloned.
	attribute :item_type_id, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :item_type_id

	## so this is also to be having a local_item_group_id.
	## that is also important at this stage.

	attribute :supplier_item_group_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	## we need also an internal item_group_id.
	## how does this play out?
	## we don't add items on transactions.
	## this is done on item groups.
	attribute :local_item_group_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	## what happens after this?
	## where to add this, inside the local item group.

	attribute :transaction_id, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :transaction_id

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}

	attribute :location_id, String, mapping: {type: 'keyword'}

	attribute :filled_amount, Float

	attribute :expiry_date, Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}
	validates_presence_of :expiry_date

	attribute :barcode, String
	validates_presence_of :barcode

	## these are set internally.
	## of the patient.
	## report can have patient id.
	## this is also present on item group.
	attribute :report_ids, Array, mapping: {type: 'keyword'}
	attribute :patient_id, String, mapping: {type: 'keyword'}

	attribute :contents_expiry_date, Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}	

	attr_accessor :statuses

	attr_accessor :reports

	attribute :space, Float, mapping: {type: 'float'}, default: 100.0
	## its quantity can be only a maximum and defaults to 100
	## and all quantities are specified as what ?
	#validate :transaction_has_received_items

	## so the root item group has to be defined.
	## here that is the main thingy
	## 
	#validate :transaction_has_items_left
	
	
	
    mapping do
      
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"

	end


	before_save do |document|
		document.cascade_id_generation(nil)
	end

	########################################################
	##
	##
	## permitted params.
	##
	##
	########################################################
	def self.permitted_params
		base = [:id,{:item => [:local_item_group_id, :supplier_item_group_id, :item_type_id, :location_id, :transaction_id, :filled_amount, :expiry_date, :barcode, :contents_expiry_date,:space]}]
		if defined? @permitted_params
			base[1][:item] << @permitted_params
			base[1][:item].flatten!
		end
		base
	end

	def self.index_properties
		{
			type: 'nested',
			properties: {
				local_item_group_id: {
					type: 'keyword'
				},
				barcode: {
					type: 'keyword'
				}
			}
		}
	end

	###########################################################
	##
	##
	## BOTH METHODS ARE USED IN Diagnostics::Report#add_item, which is in turn called from order_concern.rb
	##
	##
	###########################################################

	## @return[Boolean] : if the remaining space is 
	def has_space?(quantity)
		self.space > quantity
	end

	## @return[Float] : remaining space
	def deduct_space(quantity)
		self.space-=quantity
		self.space
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