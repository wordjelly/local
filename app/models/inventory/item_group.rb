class Inventory::ItemGroup

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-inventory-item-groups"
	document_type "inventory/item-group"

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

	attr_accessor :items

	## this is auto assigned from the barcode.
	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	## so here we want to scan the location id or have an autocomplete on it?
	attribute :location_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	attribute :item_ids, Array

	attribute :total_tests, Integer, mapping: {type: 'integer'}

	attribute :barcode, String

	attribute :item_definitions, Array[Hash]

	attribute :transaction_id, String, mapping: {type: 'keyword'}
	
	## so we can order here.
	## and we can also create the items.
	## group type needs autocomplete
	## barcode also needs autocomplete.
	attribute :group_type, String
	validates_presence_of :group_type
	validate :items_not_assigned_to_another_similar_type_group
	validate :all_items_exist

	def set_id_from_barcode
		self.id = self.barcode unless self.barcode.blank?
	end

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

	
    mapping do
      
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"

	    indexes :item_definitions, type: 'nested' do 
	    	indexes :item_type_id, type: 'keyword'
	    	indexes :quantity, type: 'integer'
	    	indexes :expiry_date, type: 'date'
	    end

	end

	## how do we clone this?
	## first give the UI Interface.
		

	def load_associated_items
		self.items ||= []
		self.item_ids.each do |iid|
			begin
				self.items << Inventory::Item.find(iid)
			rescue
			end
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
						:location_id, 
						{
							:item_definitions => [
								:item_type_id, :quantity
							]
						},
				    	:barcode, 
				    	:group_type
					]
				}
			]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
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
	def assign_id_from_name
		if self.id.blank?			
			self.id = self.name = self.barcode
		end
	end


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


end