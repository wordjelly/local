require 'elasticsearch/persistence/model'

class Inventory::Transaction

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern

	CHEQUE = "CHEQUE"
	CASH = "CASH"
	CARD = "CARD"
	CREDIT_NOTE = "CREDIT_NOTE"
	PAYMENT_MODES = [CHEQUE,CASH,CARD,CREDIT_NOTE]

	index_name "pathofast-inventory-transactions"
	
	document_type "inventory/transaction"

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	## this has to have an existing item_type
	## it has to have verification by two verifiers
	## it has to have 
	attribute :item_type_id, String, mapping: {type: 'keyword'}
	attr_accessor :item_type
	## so we load the item type for this.
	## and only then we go forward.
	## how do we get taht?
	## load if not present.

	## here we get the item_group_id
	## if received date is set, and was not set before
	## will cause an item_group to be created and will redirect to its
	## page.
	## so we have to ovverride the transactions controller for this.
	## 

	##we need a supplier id.
	attribute :supplier_id, String, mapping: {type: 'keyword'}
	attr_accessor :supplier

	##we need a quantity ordered
	attribute :quantity_ordered, Float

	##we need other information box.
	attribute :more_information, String, mapping: {type: 'keyword'}

	##we need an expected date of delivery by.
	attribute :expected_date_of_arrival, Date

	##we need an arrived on date
	attribute :arrived_on, Date

	##we need charge
	attribute :price, Float

	##we need payment by
	attribute :payment_mode, String, mapping: {type: 'keyword'}

	##we need quantity received
	attribute :quantity_received, Float

	##############################################################
	##
	##
	## CALLBACKS
	##
	##
	##############################################################
	after_find do |document|
		document.load_item_type
		document.load_supplier
	end


	## override the nameidconcern.
	## after this, comments and item_transfers
	## then items and item_groups
	## and then we are done with inventory more or less
	def assign_id_from_name
		#puts "Came to assign id from name"
		if self.name.blank?
			#puts "name is blank"
			## EDTA/ORGANIZATION-NAME/ORDER/DATETIME
			self.load_item_type
			#puts "item type name is: #{self.item_type.name}"
			#puts "created by user organization:"
			#puts self.created_by_user.organization.to_s
		
			self.name = self.item_type.name + "/" + self.created_by_user.organization.name + "/" + self.class.name + "/" + Time.now.strftime('%-d/%-m/%Y/%-l:%M%P')
			#puts "name becomes: "
			#puts self.name
			self.id = self.name
			#puts "id becomes:"
			#puts self.id.to_s
		end
	end

	def load_item_type
		unless self.item_type_id.blank?
			self.item_type = Inventory::ItemType.find(self.item_type_id)
			self.item_type.run_callbacks(:find)
		end
	end

	def load_supplier
		unless self.supplier_id.blank?
			self.supplier = Organization.find(self.supplier_id)
		end
	end

	def self.permitted_params
		base = [:id,{:transaction => [:item_type_id, :supplier_id, :quantity_ordered, :more_information,:expected_date_of_arrival, :arrived_on, :price, :payment_mode, :quantity_received]}]
		if defined? @permitted_params
			base[1][:transaction] << @permitted_params
			base[1][:transaction].flatten!
		end
		base
	end

	
	
end