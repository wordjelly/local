require 'elasticsearch/persistence/model'

class Inventory::Item

	include Elasticsearch::Persistence::Model
	## MUST BE FIRST 
	include Concerns::MissingMethodConcern
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern

	index_name "pathofast-inventory-items"

	document_type "inventory/item"	


	attribute :item_type_id, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :item_type_id, :if => Proc.new{|c| !c.barcode.blank?}

	## so this is also to be having a local_item_group_id.
	## that is also important at this stage.
	attribute :supplier_item_group_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	## so its assigned to one item group already
	## a local item group -> that was created when we came here
	## so i want to make an item group -> 
	## like a collection packet -> 
	## i want to add a barcode to it.
	## we basically want to update the local_item_group_id.
	## as we created a new local item group -> bought it -> added items to it.
	## so we can give an option (add existing item)
	## something like existing item id
	## then it can decide further.
	## 
	attribute :local_item_group_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	
	attribute :transaction_id, String, mapping: {type: 'keyword', copy_to: "search_all"}

	## so here if there is no known transaction, then we are in trouble.
	## because for the transaction the supplier is necessary.
	validates_presence_of :transaction_id, :if => Proc.new{|c| !c.barcode.blank?}

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}


	## so now lets make inventory work.
	## anand will create some item types (lithium and red top tube.)
	## then pathofast will order them.
	## then pathofast will use them in an order.
	## suppose we check existing item ?
	## would that work better -> it will see if already alloted to any patient ?
	## so we say update item.

	attribute :location_id, String, mapping: {type: 'keyword'}

	attribute :filled_amount, Float

	attribute :expiry_date, Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}
	validates_presence_of :expiry_date, :if => Proc.new{|c| !c.barcode.blank?}

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

	attribute :use_code, String, mapping: {type: 'keyword'}

	## this has to match the code parameter.
	## it is expected to be entered by the user.
	## it will be validated to match if provided.

	## @set_from : category => set_item_report_applicability
	attribute :applicable_to_report_ids, Array, mapping: {type: 'keyword'}
	
	#attribute :patient_id, String, mapping: {type: 'keyword'}

	attribute :contents_expiry_date, Date, mapping: {type: 'date', format: 'yyyy-MM-dd'}	

	attr_accessor :statuses

	attr_accessor :reports

	## @used_in : self.customizations => custom html element to render a switch, to show the use code, in case the user does not have a barcode
	## it is alwasy displayed after barcode.

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

	## the code provided in use_code, is not the same as the code provided in code.
	## @set_from : Inventory::Category#set_item_report_applicability(reports)
	attr_accessor :code_mismatch


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
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","item_type_id","supplier_item_group_id","local_item_group_id","transaction_id","filled_amount","expiry_date","report_ids","patient_id","contents_expiry_date","space","statuses","reports","name","location_id","available","applicable_to_report_ids"]
		}
	end

	def customizations(root)
		{
			"code" => '<div>If you do not have a tube with a barcode, write this code on the tube label.Please enter it into field below to confirm.</div><div>' + self.code + '</div><div style="display:none"><input type="text" value="' + self.code + '" name="order[categories][][items][][code]" /></div>' 
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

	validate :item_type_id_change

	## for eg transferring tube from one packet to another.
	## find even one order where this item exists, and it is not complete.
	validate :local_item_group_id_change

	before_validation do |document|
		document.assign_id_from_name(nil)
	end

	## can the local item group change ?
	## if its not already inside some order
	## can we chagne it ?
	## right so for that, first the patient order has to be totally completed
	## if that is done, then it can be transferred.
	## so how to check that ?
	## same here only.

	def item_type_id_change
		if self.changed_attributes.include? "item_type_id"
			if self.attributes_were["item_type_id"].blank?
			else
				self.errors.add(:item_type_id, "the item type id cannot be changed") if self.item_type_id != self.attributes_were["item_type_id"]
			end
		end
	end

	def local_item_group_id_change
		if self.changed_attributes.include? "local_item_group_id"
			unless self.attributes_were["local_item_group_id"].blank?
				if order =  Business::Order.find_incomplete_order_with_barcode(self.id.to_s)
					self.errors.add(:local_item_group_id,"this item ")
				end
			end
		end
	end



	## local item group was changed
	## is this allowed?
	## the item was assigned to someone.

	########################################################
	##
	##
	## permitted params.
	##
	##
	########################################################
	def self.permitted_params
		base = [:id,{:item => [:name,:available,:id,:local_item_group_id, :supplier_item_group_id, :item_type_id, :location_id, :transaction_id, :filled_amount, :expiry_date, :barcode, :contents_expiry_date,:space,:use_code,:code,:applicable_to_report_ids]}]
		if defined? @permitted_params
			base[1][:item] << @permitted_params
			base[1][:item].flatten!
		end
		base
	end

	## the code is checked against barcode and code both.
	def self.interface_permitted_params
		[
			:code
		]	
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
	## CALLED FROM CATEGORY#set_item_report_applicability(reports)
	## 
	##
	##########################################################
	## from where am i going to get this organization_id_report_hash.

	## @param[String] org_id : the organization id of the reports, to which this item is attempted to being added, these are
	## @param[String] category_name : the name of the category to which the user has attempted to add this item, inside the order.
	## @working : Loads the item from the inventory that corresponds to this barcode, and assigns its expiry, transaction id and other details to the item that has been created inside the category in the order.
	def get_item_details_from_barcode(org_id,category_name,report_ids,applicable,organization_id_to_report_hash)
		
		unless self.barcode.blank?

			i = Inventory::Item.find_with_organization(self.barcode,org_id)

			if i.nil?
				## doesnt exist error
				self.not_found = true
			else
				## add the transaction, name etc.
				if i.is_available?
					## then we don't add any errors.
					## add the details of expiry date, transaction, and all the other stuff here.
					## if its a denovo item, then skip these validations.
					#puts "the item category is: #{i.category}"
					#puts "the current category is: #{self.name}"
					#exit(1)
					if i.is_of_category?(category_name)
						#puts "it is of the category:#{category_name}"
						self.applicable_to_report_ids << organization_id_to_report_hash[org_id]
						applicable = true
						#puts "found item attributes are:"
						#puts i.attributes.to_s
						self.expiry_date = i.expiry_date
						self.transaction_id = i.transaction_id
						self.item_type_id = i.item_type_id
						#it.attributes.merge!({
						#	expiry_date: i.expiry_date,
						#	transaction_id: i.transaction_id,
						#	item_type_id: i.item_type_id
						#})
						#puts "the item attributes become:"
						#puts it.attributes.to_s
						#exit(1)
						#so now how to add the code.
						#so we make a custom field.
						#and render it as switch.
						#which if clicked will show that.
						return true
					else
						## not of the same category error.
						#puts "got different category error"
						self.different_category = true
					end
				else
					## expired error
					#puts "expired error."
					self.expired_or_already_used = true
				end
		
			end

		end

		return false

	end

	## @Called_from : Inventory::Category#set_item_report_applicability(reports).
	## @return[Boolean] : true/false , if the code has been provided in use_code field and it matches the original code field.
	def code_matches?
		#puts "use code is: #{self.use_code}"
		#puts "self code is: #{self.code}"
		(!self.use_code.blank?) && (self.code == self.use_code)
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
		self.space >= quantity
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
		puts "came to assign id from name, the id was: #{self.id}, the name was: #{self.name}, the barcode was: #{self.barcode}"
		if self.id.blank?	
			if self.code_matches?
				puts "code matched."
				self.id = self.name = self.code
				puts "self id : #{self.id}"
				puts "self name : #{self.name}"
				puts "self code: #{self.code}"
			else
				puts "code does not match."
				self.id = self.name = self.barcode
			end
		end
	end


	def self.bulk_search(items)
		## what about the barcode how does it get generated.
		## so basically there are items
		## like you send a list of items
		## a,b,c,d,e,f.
		## and you get the list of tests for that.
		## or you send reports
		## tests -> [lis_code, x,y,z]
		tests.each do |test|
			## tests dont have any barcode.
		end
	end

	def self.bulk_update(tests)
		
	end

	#######################################################
	##
	##
	## OVERRIDEN FROM FORM CONCERN.
	##
	##
	#######################################################
	def summary_row(args={})
		date = nil
		if !self.expiry_date.blank?
			date = self.expiry_date.strftime("%b %d %Y %I:%M %P")
		else
			date = ""
		end

		## give a dropdown for available text values
		## and nothing else can be entered.
		## i just want to test if the matching is working, and a
		## range is being picked or not.
		## then we go for dropdown.
		##puts "self name is: #{self.name}, id is: #{self.id}"

		'
			<tr>
				<td>' + (self.barcode || self.code) + '</td>
				<td>' + date + '</td>
				<td><div class="edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
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


	def self.find_organization_items(organization_id,item_type_id=nil,size=10)

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

		unless item_type_id.blank?
			query[:bool][:must] << {
				term: {
					item_type_id: item_type_id
				}
			}
		end

		search_request = Inventory::Item.search(
			{
				size: size,
				query: query
			}
		)
			
		items = []

	 	search_request.response.hits.hits.each do |hit|
	 		item = Inventory::Item.new(hit["_source"])
	 		item.id = hit["_id"]
	 		item.run_callbacks(:find)
	 		items << item
	 	end


	 	items

	end

	## @called_from : Inventory::Category#set_item_report_applicability(reports)
	## @param[String] barcode : the item barcode
	## @param[String] organization_id : the id of the organization to which it is being checked, this is checked in the owner ids.
	def self.find_with_organization(barcode,organization_id)
		
		#puts "barcode is: #{barcode}, organization id is: #{organization_id}"

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
		#puts "checking category: #{category}"
		begin
			item_type = Inventory::ItemType.find(self.item_type_id)
			#puts "item type is:"
			#puts item_type.attributes.to_s
			item_type.categories.include? category
		rescue => e
			false
		end
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
		self.errors.add(:code_mismatch,"The code entered does not match the code provided, please try again.") if self.code_mismatch == true
	end

end