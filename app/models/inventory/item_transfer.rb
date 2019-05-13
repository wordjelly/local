'elasticsearch/persistence/model'
class Inventory::ItemTransfer
	
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-inventory-item-transfers"

	attribute :name, String, mapping: {type: 'keyword'}
	validates_presence_of :name

	attribute :to_location_id, String, mapping: {type: 'keyword'}
	validate :from_location_id_exists

	attribute :from_location_id, String, mapping: {type: 'keyword'}
	validate :to_location_id_exists

	attribute :from_user_id, String, mapping: {type: 'keyword'}
	validate :from_user_id_exists

	attribute :to_user_id, String, mapping: {type: 'keyword'}
	validate :to_user_id_exists


	attribute :transaction_ids, Array, mapping: {type: 'keyword'}

	## if only a transaction is provided, then we have to have the item quantity, and we have to have the previous item transfer id, or it has to be the first transaction.
	attribute :item_quantity, Integer

	## if its an item_id, there will be only one transaction id.
	attribute :item_id, String, mapping: {type: 'keyword'}

	## if its an item_group -> there will be multiple transactions, one for each item in the item_group.
	attribute :item_group_id, String, mapping: {type: 'keyword'}

	## this is optional.
	attribute :previous_item_transfer_id, String, mapping: {type: 'keyword'}
	


	###########################################################33
	##
	##
	## VALIDATIONS
	##
	##
	############################################################
	def from_location_id_exists
		self.errors.add(:from_location_id, "this id does not exist") unless object_exists?("Location",self.from_location_id)
	end

	def to_location_id_exists
		self.errors.add(:to_location_id, "this id does not exist") unless object_exists?("Location",self.to_location_id)
	end

	def from_user_id_exists
		self.errors.add(:from_user_id, "this id does not exist") unless object_exists?("User",self.from_user_id)
	end

	def to_user_id_exists
		self.errors.add(:to_user_id, "this id does not exist") unless object_exists?("User",self.to_user_id)
	end

	def transaction_id_exists
		self.errors.add(:transaction_id, "this id does not exist") unless object_exists?("Inventory::Transaction",self.transaction_id)
	end

	def previous_item_transfer_id_exists
		self.errors.add(:previous_item_transfer_id, "this id does not exist") unless object_exists?("Inventory::ItemTransfer",self.previous_item_transfer_id)
	end

	############################################################
	##
	##
	## ADDING ORGANIZATION IDS FOR TRANSFERS OF OWNERSHIP.
	##  
	##
	##
	############################################################

	def add_recipients_organization_id_to_all_items_transferred

		## when you do a transfer that refers to a transaction.
		## or for an item individually
		## or for an item group.
		## then it will have the barcodes.
		## but if its for a transaction, and that transaction involves barcoded items, then you cannot do the transfer.
		## if it does not involve the barcoded items, then you can transfer but then you can only transfer

	end

end