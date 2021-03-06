class Inventory::ItemGroup

	include Elasticsearch::Persistence::Model
	include Concerns::MissingMethodConcern
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::CallbacksConcern

	## we were able to create our own item groups
	## 

	index_name "pathofast-inventory-item-groups"
	document_type "inventory/item-group"

	## lets keep all the ids like this
	## organization_name/document_type/date/{name- if it exists?}
	## then at least the name can be created.
	## and camelize the whole thing.
	## so it wants to make a barcode.
	## it has to first create one.
	## if it goes through, then proceed otherwise forget it.
	## we make another object called a barcode.
	## and then we proceed.
	## What else
	## what about the transactions.
	## it creates a barcode document.
	## then it creates this document.
	## so that ensures uniqueness across all indices.
	## so its currently not showing the item groups in the transaction.
	attr_accessor :items

	attribute :cloned_from_item_group_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	## this is auto assigned from the barcode.
	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	
	## so we just update it.
	## update an existing item ?
	## no we update it -> 
	## transfer existing.
	## previous item groups
	## we add one thing like this.
	## what else
	## transfer -> ?

	## so here we want to scan the location id or have an autocomplete on it?
	attribute :location_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	attribute :item_ids, Array

	attribute :total_tests, Integer, mapping: {type: 'integer'}

	attribute :barcode, String

	attribute :item_definitions, Array[Hash]

	attribute :transaction_id, String, mapping: {type: 'keyword'}
	attr_accessor :transaction
	
	attribute :supplier_id, String, mapping: {type: 'keyword'}

	## new item form is opened
	## not from here
	## so what we will do is select that
	## if its before save ?
	## or what ?
	## this is not easy.
	## the supplier id will be the self.
	## unless it is provided.
	## in that case, if we are cloning.
	## then we have to specify it.
	## so we can order here.
	## and we can also create the items.
	## group type needs autocomplete
	## barcode also needs autocomplete.
	attribute :group_type, String
	validates_presence_of :group_type
	#validate :items_not_assigned_to_another_similar_type_group
	#validate :all_items_exist

	## lets say it calculates all the requirements
	## and makes an array out of them.
	## it assigns item ids to whatever is there
	## how does it know which test can and cannot be performed.
	## i want to finish location and all this today itself, with item requirement 
	## determination.
	## and with addition and removal of reports from an
	## order.
	## the internal determination of requirements
	## and assignment of packets.
	## all this should be done by 
	## now it goes over each report
	## checks, if any of its requirements are fulfilled
	## with a registered item, and sufficient quantity, and registers those reports to the all its available items.
	## that is how it works.

	attribute :report_ids, Array, mapping: {type: 'keyword'}
	attribute :patient_id, String, mapping: {type: 'keyword'}

	before_validation do |document|
		document.cascade_id_generation(nil)
	end

	before_save do |document|
		if document.supplier_id.blank?
			document.supplier_id = document.created_by_user.organization.id.to_s
		end
		if document.created_by_user.organization.is_a_supplier?
			document.public = Concerns::OwnersConcern::IS_PUBLIC
		end
	end

	after_find do |document|
		document.load_transaction
		document.load_associate_item_counts
	end

	validate :item_definitions_unique
	### TODO.
	### the same item_type_id is not added twice to a given item group.
	def item_definitions_unique

	end
	
=begin
	def all_items_exist
		self.item_ids.each do |iid|
			begin
				Inventory::Item.find(iid)
			rescue
				puts "the item id not found is:"
				puts iid
				self.errors.add(:item_ids,"this item #{iid} does not exist")
			end
		end	
	end	

	def items_not_assigned_to_another_similar_type_group
		item_id_queries = self.item_ids.map{|c|
			c = {
					term: {
						item_ids: c
					}
				}
		}

		puts "item id queries are:"
		puts JSON.pretty_generate(item_id_queries)
		puts "------------------------------------------------"

		response = Inventory::ItemGroup.search({
			query: {
				bool: {
					must: [
						{
							bool: {
								should: item_id_queries
							}
						},
						{
							term: {
								group_type: self.group_type
							}
						}
					]
				}
			}
		})
		if response.results.size > 0
			self.errors.add(:item_ids, "some of these items have already been assigned to other item groups")
		end
	end
=end
	
    mapping do
      
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"
	   	
	   	## so if its an existing item
	   	## we give such an option
	   	## in that view
	   	## so we use the barcode as the id.
	   	## just give a custom field.
	   	## on click handler etc.
	    indexes :item_definitions, type: 'nested' do 
	    	indexes :item_type_id, type: 'keyword'
	    	indexes :quantity, type: 'integer'
	    	indexes :expiry_date, type: 'date', format: "yyyy-MM-dd"
	    end
	end

	## that will hit item create
	## actually that is not the right entry point.
	## what we can do is what ?
	## transfer_existing_item
	## prompt for the barcode using javascript -> send to edit that item, so its just a small form issue.

	def load_associate_item_counts
		search_request = Inventory::Item.search({
			query: {
				term: {
					local_item_group_id: self.id.to_s
				}
			},
			aggregations: {
				item_type: {
					terms: {
						field: "item_type_id"
					}
				}
			}
		})
		search_request.response.aggregations.item_type.buckets.each do |item_type_bucket|
			item_type_id = item_type_bucket["key"]
			self.item_definitions.map{|item_definition|
				if item_definition["item_type_id"] == item_type_id
					item_definition["total_items_created"] = item_type_bucket["doc_count"]
				end
			}
		end
	end

	## okay so now should have a link to see those items
	## so it will be an index request to item.
	## see all items will query.
	## that works.
	## next is item transfer , and validation requirements.
	## so now let me look at comments.
	## when you view all the transactions, please give a dropdown for the local item groups.

	def load_transaction
		if self.transaction.blank?
			self.transaction = Inventory::Transaction.find(self.transaction_id) unless self.transaction_id.blank?
			self.transaction.run_callbacks(:find) unless self.transaction_id.blank?
		end
	end

	def prepare_items_to_add_to_order
		load_associated_items 
		response = {
			"item_requirements" => {}
		}
		self.items.each do |item|
			response["item_requirements"][item.item_type] ||= []
			response["item_requirements"][item.item_type] << 
			{"barcode" => item.id.to_s, "index" => response["item_requirements"][item.item_type].size, "type" => item.item_type}
		end

		response["item_requirements"]
	end

	########################################################
	##
	##
	## PERMITTED PARAMS.
	##
	##
	########################################################
	def self.permitted_params
		base = [
				:id,
				{:item_group => 
					[
						:name,
						:location_id, 
						{
							:item_definitions => [
								:item_type_id, :quantity, :expiry_date
							]
						},
				    	:barcode, 
				    	:group_type
					]
				}
			]
		if defined? @permitted_params
			base[1][:item_group] << @permitted_params
			base[1][:item_group].flatten!
		end
		base
	end

	########################################################
	##
	##
	## METHOD OVERRIDEN FROM NAMEIDCONCERN
	##
	##
	########################################################
=begin
	def assign_id_from_name
		puts "is the self id blank?"
		puts self.id.to_s
		if self.id.blank?
			## so here the barcode is being used as the id.
			## let us use some common sense if possible		
			## barcode cannot be set on item_groups in this way
			## this barcode will also be copied to the local one.
			## okay so suppose that item has a barcode.
			## what is the new barcode.
			## till it has been assigned it has no barcode. 
			##self.id = self.name = self.barcode
			##barcode can be added later.
			self.id = self.created_by_user.organization.id.to_s + "--" + Time.now.to_s + "--" + self.class.name.to_s + "--" + self.name.to_s + "--" + BSON::ObjectId.new.to_s
			self.id += "--" + self.barcode unless self.barcode.blank?

			puts "set the id of self to : #{self.id.to_s}"
		else
			puts "teh self id is not blank."
		end
	end
=end
	
	## what is there in transfer?
	## just give the item from one person to another.
	## or transfer location
	## or pick up.
	## after this i go to item requirement and status 
	## and steps
	## and routines.
	## last we come to reports and orders.	
	########################################################
	##
	##
	## METHOD OVERRIDEN FROM OWNER'S CONCERN.
	## THIS METHOD SHOULD BE CALLED ON UPDATE, IN CASE 
	## SOME ITEMS ARE REMOVED/ADDED.
	## BUT WHO CAN ADD/REMOVE ?
	##
	########################################################
	def add_owner(user_id)
		begin
			u = User.find(user_id)
			self.owner_ids << u.organization.id.to_s
			self.items.each do |item|
				item.add_owner(user_id)
			end
			self.save
		rescue
			self.errors.add(:owner_ids, "could not add the recipient to the owner ids of the object #owners_concern.rb")
		end
	end


	## @return[Array] : items -> array of Inventory::Item instances, which are a part of a transaction that was received.
	## it searches for items that have this item_group as the local_item_group_id. 
	## so it will only find those items, which were add to this group, after a transaction was done, and item_groups were received, and then items were added to it.
	def get_components_for_transfer
		items = []
        search_request = Inventory::Item.search({
			query: {
				term: {
					local_item_group_id: self.id.to_s
				}
			}
		})
		search_request.response.hits.hits.each do |hit|
			item = Inventory::Item.new(hit["_source"])
			item.id = hit["_id"]
			item.run_callbacks(:find)
			items << item
		end
		items
    end

    ############################################################
    ##
    ##
    ## HELPERS
    ##
    ##
    ############################################################
    ## @return[Hash]
    ## key -> category_name
    ## value -> [item_id_one,item_id_two]
    ## @called_from : order_concern.rb#update_categories_from_item_group 
    def get_items_grouped_by_category_name
    	result = {}
    	puts "self id is: #{self.id.to_s}"
    	search_request = Inventory::Item.search({
			query: {
				term: {
					local_item_group_id: self.id.to_s
				}
			},
			aggregations: {
				categories: {
					terms: {
						field: "categories"
					},
					aggs: {
						item_id: {
							terms: {
								field: "barcode"
							}
						}
					}
				}
			}
		})
		search_request.response.aggregations.categories.buckets.each do |category_bucket|
			category = category_bucket["key"]
			item_ids = []
			category_bucket.item_id.buckets.each do |item_bucket|
				item_ids << item_bucket["key"] 
			end
			result[category] = item_ids
		end
		result
    end


    def self.find_organization_item_groups(organization_id)
    	
    	query = {
			bool: {
				must: [
					{
						term: {
							owner_ids: organization_id
						}
					}
				]
			}
		}

		search_request = Inventory::ItemGroup.search(
			{
				size: 10,
				query: query
			}
		)
			
		item_groups = []

	 	search_request.response.hits.hits.each do |hit|
	 		item_group = Inventory::ItemGroup.new(hit["_source"])
	 		item_group.id = hit["_id"]
	 		item_group.run_callbacks(:find)
	 		item_groups << item_group
	 	end


	 	item_groups

    end	

end