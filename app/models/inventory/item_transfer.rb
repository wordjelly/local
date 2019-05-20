'elasticsearch/persistence/model'
class Inventory::ItemTransfer
	
	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	## targets for today is 
	## finish item, item_group, item_group nested, item transfer
	## and inventory apis, and solve search issue.
	## send api's and screens to these fuckers.

	index_name "pathofast-inventory-item-transfers"
	document_type "inventory/item-transfer"

	### OPTION ONE
	attribute :item_quantity, Integer, default: 1

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
	
	attribute :barcode, String, mapping: {type: 'keyword', copy_to: "search_all"}

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


	def self.permitted_params
		base = [:id,{:item_type => [:to_location_id, :from_user_id, {:transaction_ids => []}, :item_quantity, :barcode]}]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		base
	end

	

end