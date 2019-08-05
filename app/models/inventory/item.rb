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

	## only the barcode has to be validated, depending again on the context
	## for eg if the barcode exists in the inventory or not.
	## now here is where it gets complicated.
	## check in the organization that is creating the order
	## what if the patient is creating the order.
	## so here comes the problem.
	## no we have the report copied over.
	## so we have to check in that context.
	## if you chose outsource to x.
	## then it will check in their inventory.
	## not your's
	attribute :barcode, String
	validates_presence_of :barcode


	## some validations to be done if 
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

	## DEFAULT : 1 (AVAILABLE)
	## -1 : NOT AVAILABLE
	attribute :available, Integer, mapping: {type: 'integer'}, default: 1

	#########################################################
	##
	##
	## before_validation a method is called on order
	## it take each category , gets the reports to which it is applicable
	## then for each of those reports, checks which organization they
	## belong to, (the outsourced organization), and then sets that
	## on each of the items in the category.
	## this is then used in the item validation, to see if this 
	## item's barcode is unique and has never been used inside that
	## organization
	## suppose i scan a serum tube and it gets registered 
	## either it has to be unique to me 
	## we want to outsource homocysteiene.
	## and we want to do urea and creat in the lab.
	## we scanned our own code.
	## and now we want to send it outside.
	## so for homocysteine it doesn't register it on the report.
	## as it is not from that organization.
	## so you can add a barcode, it will check against all the applicable reports
	## if it is unique for both, it will register
	## otherwise only where required
	## and then it can go forwards.
	## is this necessary on items.
	## so just take the reports
	## check their origin
	## check the items origins
	## and register it wherever applicable.
	#########################################################
	
	#########################################################
	##
	##
	## SET FROM Business::Order#add_parent_details (which is in turn defined in missing_method_concern, and is called before_validation)
	##
	## it basically iterates all the children and adds these parent attributes , for reports, categories, payments.
	## this is then used in the validations of item, to do conditional behaviour.
	##
	#########################################################
	#attribute :order_id, String, mapping: {type: 'keyword'}
	#attribute :category_id, String, mapping: {type: 'keyword'}
	
	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","item_type_id","supplier_item_group_id","local_item_group_id","transaction_id","filled_amount","expiry_date","report_ids","patient_id","contents_expiry_date","space","statuses","reports","name","location_id"]
		}
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
	def assign_id_from_name(organization_id)
		## so this is done
		## make an item and item group controller.
		## and views
		## then we move to item transfer.
		if self.id.blank?			
			self.id = self.name = self.barcode
		end
	end

	#######################################################
	##
	##
	## OVERRIDEN FROM FORM CONCERN.
	##
	##
	#######################################################
	def summary_row(args={})
		'''
			<tr>
				<td>#{self.name}</td>
				<td>#{self.expiry_date}</td>
				<td><div class="edit_nested_object">Edit</div></td>
			</tr>
		'''
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers
		'''
			<thead>
	          <tr>
	              <th>Name</th>
	              <th>Expiry Date</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	## @return[Boolean] true/false, if the item has not been used for any other order, and has not expired.
	## the method assumes that the available flag will be turned on and off in the item, depending on whether the item has been recycled or utilized inside another order.
	def is_available?
		if self.available == 1
			if Date.today < self.expiry_date
				return true
			end
		end
		return false
	end

	## @param[String] barcode : the item barcode
	## @param[String] organization_id : the id of the organization to which it is being checked, this is checked in the owner ids.
	def self.find_with_organization(barcode,organization_id)
		query = {
			bool: {
				must: [
					{
						term: {
							barcode: {
								value: barcode
							}
						}
					},
					{
						term: {
							owner_ids: {
								value: organization_id
							}
						}
					}
				]
			}
		}

		search_request = Inventory::Item.search(
			{
				size: 1,
				query: query
			}
		)
			
		item = nil

	 	search_request.response.hits.hits.each do |hit|
	 		item = Inventory::Item.new(hit["_source"])
	 		item.id = hit["_id"]
	 		item.run_callbacks(:find)
	 	end

	 	item
	end

end