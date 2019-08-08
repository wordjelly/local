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

	
	attribute :item_type_id, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :item_type_id, :if => Proc.new{|c| !c.barcode.blank?}

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
	validates_presence_of :transaction_id, :if => Proc.new{|c| !c.barcode.blank?}

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}


	## so now lets make inventory work.
	## anand will create some item types (lithium and red top tube.)
	## then pathofast will order them.
	## then pathofast will use them in an order.


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
	#validates_presence_of :barcode

	## suppose that we don't have a barcode
	## then how does it assign the id, and the name.
	## that can come from the has_code.
	## in that case, expiry date has to be provided.
	## but transaction id is not necessary.

	## used in case the user does not have a barcoded tube
	## the user is told to write this code on the tube
	## alongwith the name of the patient.
	## this is also used in case.
	attribute :code, String, mapping: {type: 'keyword'}, default: SecureRandom.hex(3)

	## this has to match the code parameter.
	## it is expected to be entered by the user.
	## it will be validated to match if provided.
	attribute :use_code, String, mapping: {type: 'keyword'}

	## @set_from : category => set_item_report_applicability
	attribute :applicable_to_report_ids, Array, mapping: {type: 'keyword'}
	
	#attribute :patient_id, String, mapping: {type: 'keyword'}

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

		
	## @set_from : Inventory::Category#set_item_report_applicability(reports)
	## if this is set to true, it will be caught in the validation
	## function named: Inventory::Item#check_applicability
	attr_accessor :not_applicable_to_any_reports

	## the item is not found
	## @set_from : Inventory::Category#set_item_report_applicability(reports)
	attr_accessor :not_found

	## the item has expired or it has been used elsewhere 
	## @set_from : Inventory::Category#set_item_report_applicability(reports)
	attr_accessor :expired_or_already_used

	## the item category is not the same as the current category
	## @set_from : Inventory::Category#set_item_report_applicability(reports)
	attr_accessor :different_category

	validate :check_applicability
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
		
	## all the use_code and code are kept hidden.
	## we will use javascript to enable the working of that.
	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","item_type_id","supplier_item_group_id","local_item_group_id","transaction_id","filled_amount","expiry_date","report_ids","patient_id","contents_expiry_date","space","statuses","reports","name","location_id","use_code","code","available","applicable_to_report_ids"]
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


	before_validation do |document|
		## here we don't need to call cascade_id_generation
		## because there are no children.
		## so we directly call assign_id from name.
		document.assign_id_from_name(nil)
	end

	########################################################
	##
	##
	## permitted params.
	##
	##
	########################################################
	def self.permitted_params
		base = [:id,{:item => [:local_item_group_id, :supplier_item_group_id, :item_type_id, :location_id, :transaction_id, :filled_amount, :expiry_date, :barcode, :contents_expiry_date,:space,:use_code,:code,:applicable_to_report_ids]}]
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
		'
			<tr>
				<td>' + self.name + '</td>
				<td>' + (self.expiry_date || "") + '</td>
				<td><div class="edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
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

	## @called_from : Inventory::Category#set_item_report_applicability(reports)
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

	 	#puts "returning the item : #{item}"

	 	item

	 	## if this item has been found.
	 	## get its item type id, and check if that is
	 	## having the category as is mentioned here.

	end

	## @called_from : Inventory::Category#set_item_report_applicability(reports)
	## @param[String] category : the name fo the category
	## @return[Boolean] true/false : gets the item_type_id, and finds the itemType, and checks whether the provided category is mentioned in this item_type
	def is_of_category?(category)
		#puts "the item type id is: #{self.item_type_id}"
		begin
			item_group = Inventory::ItemType.find(self.item_type_id)
			#puts "item group is:"
			#puts item_group.attributes.to_s
			item_group.categories.include? category
		rescue => e
			puts "find error si:"
			puts e.to_s
			false
		end
		#exit(1)
	end

	######################################################
	##
	##
	## CHECK APPLICABILITY
	##
	##
	######################################################
	def check_applicability
		self.errors.add(:applicable_to_report_ids,"The Item cannot be used as the barcode is invalid, use another barcode/tube") if (self.not_applicable_to_any_reports == true)
		self.errors.add(:barcode, "This barcode was not found") if self.not_found == true
		self.errors.add(:barcode, "This barcode was already used, or the tube has expired") if self.expired_or_already_used == true
		self.errors.add(:different_category, "This tube is a of a different type and cannot be used") if self.different_category == true
	end

end