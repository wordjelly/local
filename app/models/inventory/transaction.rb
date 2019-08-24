require 'elasticsearch/persistence/model'

class Inventory::Transaction

	include Elasticsearch::Persistence::Model
		include Concerns::MissingMethodConcern

	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	#include Concerns::VersionedConcern

	CHEQUE = "CHEQUE"
	CASH = "CASH"
	CARD = "CARD"
	CREDIT_NOTE = "CREDIT_NOTE"
	PAYMENT_MODES = [CHEQUE,CASH,CARD,CREDIT_NOTE]

	index_name "pathofast-inventory-transactions"
	
	document_type "inventory/transaction"

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}

	## this is the incoming.
	## should i name it as such.
	attribute :supplier_item_group_id,String, mapping: {type: 'keyword', copy_to: "search_all"}
	attr_accessor :supplier_item_group
	attr_accessor :local_item_groups

	attribute :supplier_id, String, mapping: {type: 'keyword'}
	attr_accessor :supplier

	##we need a quantity ordered
	attribute :quantity_ordered, Float

	##we need other information box.
	attribute :more_information, String, mapping: {type: 'keyword'}

	##we need an expected date of delivery by.
	attribute :expected_date_of_arrival, Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}

	##we need an arrived on date
	attribute :arrived_on, Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}

	##we need charge
	attribute :price, Float

	##we need payment by
	attribute :payment_mode, String, mapping: {type: 'keyword'}

	##we need quantity received
	attribute :quantity_received, Float

	before_validation do |document|
		document.cascade_id_generation(nil)
	end

	##############################################################
	##
	##
	## CALLBACKS
	##
	##
	##############################################################
	after_find do |document|
		document.load_supplier_item_group
		document.load_supplier
		document.load_local_item_groups
	end


	## override the nameidconcern.
	## after this, comments and item_transfers
	## then items and item_groups
	## and then we are done with inventory more or less


	## callbacks will be run, only we skip the finding of the transaction again.
	## since we already have access to the transaction.
	## so in the show callback we directly set the transaction from here itself.
	def load_supplier_item_group
		unless self.supplier_item_group_id.blank?
			if self.supplier_item_group.blank?
				self.supplier_item_group = Inventory::ItemGroup.find(self.supplier_item_group_id)
				self.supplier_item_group.transaction = self
				self.supplier_item_group.run_callbacks(:find)
			end
		end
	end

	## okay so now check if all this works.
	## so we now add a few items.
	## i want some more information to be shown in the search bar.
	## or i can check this bit.
	def load_local_item_groups
		unless self.id.blank?
			response = Inventory::ItemGroup.search({
				query: {
					bool: {
						must: [
							{
								term: {
									transaction_id: self.id.to_s
								}
							},
							{
								term: {
									cloned_from_item_group_id: self.supplier_item_group_id
								}
							}
						]
					}
				}
			})

			puts "teh local item group is:" 
			
			puts response.results.size.to_s
			
			self.local_item_groups = []
			
			response.results.each do |hit|
				local_item_group = Inventory::ItemGroup.find(hit.id.to_s)
				## this is important to avoid an endless loop.
				local_item_group.transaction = self
				local_item_group.run_callbacks(:find)	
				## here assign the current transaction.
				self.local_item_groups << local_item_group
			end
		end

	end


	## quantity received is not getting properly updated.
	## this will take the supplier_item_group.
	## and make a new item_group out of it.
	## this is expected to happen after save.
	## for tomorrow first he needs to set the organization
	## he needs an image for that.
	## he also needs to ask for the role of the organization.
	## so lets see if this works.
	def clone_local_item_groups
		## there can be n such groups.
		self.quantity_received.to_i.times do 
			local_item_group = Inventory::ItemGroup.new(self.supplier_item_group.attributes.except(:id,:barcode,:owner_ids,:currently_held_by_organization,:name))
			## this should ideally be working.
			local_item_group.created_by_user = self.created_by_user
			local_item_group.cloned_from_item_group_id = self.supplier_item_group.id.to_s
			local_item_group.transaction_id = self.id.to_s
			#local_item_group.assign_id_from_name
			begin
				## here do that save thingy.
				if Rails.env.test? || Rails.env.development?
					if ENV["CREATE_UNIQUE_RECORDS"].blank?
						local_item_group.save(op_type: "create")
					elsif ENV["CREATE_UNIQUE_RECORDS"] == "no"
						local_item_group.save
					end
				else
					local_item_group.save(op_type: "create")
				end
				#puts "the local item group was created."
				#puts "the errors are:"
				#puts local_item_group.errors.full_messages
				#puts "its id is"
				#puts local_item_group.id.to_s
				#puts "the created by user email is:"
				#puts self.created_by_user.email.to_s
				#puts "-------------------------------"
				unless local_item_group.errors.blank?
					self.errors.add(:local_item_groups, local_item_group.errors.full_messages.to_s)
				end
			rescue => e
				puts e.to_s
				self.errors.add(:local_item_groups, "someone else tried to create an item group at the same time on your organization")
			end
		end
	end

	def load_supplier
		unless self.supplier_id.blank?
			self.supplier = Organization.find(self.supplier_id)
		end
	end

	def self.permitted_params
		base = [:id,{:transaction => [:supplier_item_group_id, :supplier_id, :quantity_ordered, :more_information,:expected_date_of_arrival, :arrived_on, :price, :payment_mode, :quantity_received]}]
		if defined? @permitted_params
			base[1][:transaction] << @permitted_params
			base[1][:transaction].flatten!
		end
		base
	end

	###########################################################
	##
	##
	## UTILITY METHOD
	##
	##
	###########################################################
	def received?
		!self.quantity_received.blank?
	end

	before_validation do |document|
		document.cascade_id_generation(nil)
	end

	before_save do |document|
		#puts "document is received check?"
		#puts document.quantity_received.to_s
		if document.received?
			#puts "document is received."
			if document.local_item_groups.blank?
				#puts "local item group is blank."
				document.clone_local_item_groups
			end
		end
	
		
	
	end
		
end