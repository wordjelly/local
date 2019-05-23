'elasticsearch/persistence/model'
class Inventory::ItemTransfer
	
	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::EsBulkIndexConcern

	attr_accessor :to_user
	## what is the object that is being transferred ?
	attr_accessor :transferred_object
	## this object has to also be loaded.
	## and its after_find callbacks have to be called.

	## targets for today is 
	## finish item, item_group, item_group nested, item transfer
	## and inventory apis, and solve search issue.
	## send api's and screens to these fuckers.

	index_name "pathofast-inventory-item-transfers"
	document_type "inventory/item-transfer"

	### OPTION ONE
	attribute :quantity, Integer, default: 1

	## then the recipient user id.
	## so we keep two different forms. to be shown., based on incoming parameters.
	attribute :to_user_id, String, mapping: {type: 'keyword', copy_to: 'search_all'}
	validates_presence_of :to_user_id
	## this will default to the created_by_user

	## then what else is required.
	## what about a reason?
	attribute :reason, String, mapping: {type: 'text', copy_to: 'search_all'}
	validates_presence_of :reason

	## what else.
	## the transaction id.
	## if we are transferring an item_group?
	## is it necessary.
	## not required.
	## if its an item_group.
	attribute :transaction_ids, Array, mapping: {type: 'keyword', copy_to: 'search_all'}

	##if not present, then will be provided internally from the barcode.	
	attribute :to_location_id, String, mapping: {type: 'keyword'}

	attribute :from_location_id, String, mapping: {type: 'keyword'}
	
	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :name
		
	## barcodes of all items that are involved in the transfer
	attribute :barcodes, Array, mapping: {type: 'keyword', copy_to: "search_all"}

	## transaction ids, of all the items that are involved in the transfer
	## these are to be internally derived.
	attribute :transaction_ids, Array, mapping: {type: 'keyword', copy_to: "search_all"}



	attribute :model_id, String, mapping: {type: 'keyword', copy_to: 'search_all'}

	attribute :model_class, String, mapping: {type: 'keyword', copy_to: 'search_all'}


	## give option at item.
	## or transaction
	## give to user
	## shift to location.
	## so give this in the options.
	## and basically it goes to the item_transfer form.
	## after this i will do item bundle.
	## 
	###########################################################33
	##
	##
	## VALIDATIONS
	##
	##
	############################################################
	
	############################################################
	##
	##
	## ADDING ORGANIZATION IDS FOR TRANSFERS OF OWNERSHIP.
	##  
	##
	##
	############################################################
	## lets have a field called transfer
	## it will encapsulate the logic.
	## 
	## so this is the big bet here.
	## given the model id.
	## we have to get its constituents.
	## let's give them a transferrable concern?
	## they have to transfer basically.
	## provided that that item is owned by the user at hand
	## then take all the components, and blow them out.
	## so in a transaction, this will have to be bulked.
	## so the method get_components will be called.
	## if its an item group it will be done.
	## if its a transaction, and any of the items have been barcoded it will not be.
	## so take the transaction
	## take the local item groups
	## take their items
	## and transfer everything in a single bulk call.
	## or keep it as it is.
	## so give it a transferrable concern.
	## that is the only way to do it.
	## it has to accumulate bulk calls.
	def set_transaction_ids
		unless self.barcode.blank?
			response = Elasticsearch::Persistence.client.search index: "pathofast-item-*", body: {
				size: 1,
				query: {
					ids: {
						values: [self.barcode]
					}
				}
			}
			mash = Hashie::Mash.new response 
			@search_results = mash.hits.hits.map{|c|
				c = c["_type"].underscore.classify.constantize.new(c["_source"].merge(:id => c["_id"]))
				if c.created_by_user.can_transfer?(c)
					c.add_owner(self.to_user_id)
				end
				c
			}
		end
	end

	def set_barcodes

	end

	def set_to_user
		self.to_user = User.find(self.to_user_id)
	end

	def set_transferred_object
		self.transferred_object = self.model_class.constantize.find(self.model_id)
		self.transferred_object.run_callbacks(:after_find)
	end


	###########################################################
	##
	##
	## does it do this before save?
	## what happens if it fails in the bulks.
	## 
	##
	###########################################################
	before_save do |document|
		document.set_to_user
		document.set_transferred_object
		document.transferred_object.transfer(document.to_user).each do |update_request|
			Inventory::ItemTransfer.add_bulk_item(update_request)
		end
		Inventory::ItemTransfer.flush_bulk
	end

	## this should transfer shit easily.
	## we can also remove, but upto this point, things should be pretty well established.
	
	def self.permitted_params
		base = [:id,{:item_transfer => [:to_location_id, :to_user_id, :item_quantity, :model_id, :model_class, :quantity]}]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		base
	end

	

end