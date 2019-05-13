'elasticsearch/persistence/model'
class Inventory::ItemTransfer
	
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-inventory-item-transfers"
	document_type "inventory/item-transfer"

	attribute :name, String, mapping: {type: 'keyword'}
	validates_presence_of :name

	attribute :to_location_id, String, mapping: {type: 'keyword'}

	attribute :from_location_id, String, mapping: {type: 'keyword'}
	

	attribute :from_user_id, String, mapping: {type: 'keyword'}
	

	## this has to be got before_save
	## from the item_ids/item_group_ids
	## unless it is already provided.
	attribute :transaction_ids, Array, mapping: {type: 'keyword'}
	validates_presence_of :transaction_ids, :if => Proc.new{|c| (c.item_id.blank? && c.item_group_id.blank?)}

	## if only a transaction is provided, then we have to have the item quantity, and we have to have the previous item transfer id, or it has to be the first transaction.
	attribute :item_quantity, Integer
	

	attribute :barcode, String, mapping: {type: 'keyword'}
	###########################################################33
	##
	##
	## VALIDATIONS
	##
	##
	############################################################
	def to_location_id_exists
		self.errors.add(:to_location_id, "this id does not exist") unless object_exists?("Location",self.to_location_id)
	end

	def from_user_id_exists
		self.errors.add(:from_user_id, "this id does not exist") unless object_exists?("User",self.from_user_id)
	end
	############################################################
	##
	##
	## ADDING ORGANIZATION IDS FOR TRANSFERS OF OWNERSHIP.
	##  
	##
	##
	############################################################
	before_save do |document|

		## get the transaction ids for the 
		## get the previous transfer
		## check if that user, and the from_user is the same or not.
		## 
		## get the current holding user, and set it as from that user.
	end

	def build_query
		{
			size: 1,
			query: {
				ids: {
					values: [self.barcode]
				}
			}
		}
	end

	def set_transaction_ids
		unless self.barcode.blank?
			response = Elasticsearch::Persistence.client.search index: "pathofast-item-*", body: build_query
			mash = Hashie::Mash.new response 
			@search_results = mash.hits.hits.map{|c|
				c = c["_type"].underscore.classify.constantize.new(c["_source"].merge(:id => c["_id"]))
				c
			}
			## these are the search results
			## there will be only one.
			## that is the item_group or whatever
			## we have to set its transaction id.
			## we call the method on item_group
			## and item
			## called get_transaction.
		end
	end

	def add_recipients_organization_id_to_all_items_transferred
		## when you do a transfer that refers to a transaction.
		## or for an item individually
		## or for an item group.
		## then it will have the barcodes.
		## but if its for a transaction, and that transaction involves barcoded items, then you cannot do the transfer.
		## if it does not involve the barcoded items, then you can transfer but then you can only transfer
	end

	def self.permitted_params
		base = [:id,{:item_type => [:to_location_id, :from_user_id, {:transaction_ids => []}, :item_quantity, :barcode]}]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		#puts "the base becomes:"
		#puts base.to_s
		base
	end

end