require 'elasticsearch/persistence/model'

class Inventory::Category

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
	include Concerns::CallbacksConcern

	## how to make a local item group.

	attribute :name, String, mapping: {type: 'keyword'}
	## this is a percentage.
	attribute :quantity, Float, mapping: {type: 'float'}, default: 100
	## these will be the items added.
	## so i had added it here.
	attribute :items, Array[Inventory::Item]
	attribute :required_for_reports, Array, mapping: {type: 'keyword'}, default: []
	attribute :optional_for_reports , Array, mapping: {type: 'keyword'}, default: []

		
	## so let me do this first.
	## this is a permitted parameter.
	## intended to be set from outside.
	## if set, then this category's item will be assigned to all the tests
	## in the lis.
	## if this parameter changes, then the paramter on the order called
	## changed_for_lis also changes.
	attribute :use_category_for_lis, Integer, mapping: {type: 'integer'}, default: 0

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","name","quantity","barcode"]
		}
	end

	def self.permitted_params
		[
			:id,
			:quantity,
			:name,
			:use_category_for_lis,
			{
				:items => Inventory::Item.permitted_params[1][:item]
			},
			{
				:required_for_reports => []
			},
			{
				:optional_for_reports => []
			}
		]
	end

	def self.index_properties	
		{
			quantity: {
				type: 'float'
			},
			name: {
				type: 'keyword'
			},
			items: Inventory::Item.index_properties,
			required_for_reports: {
				type: 'keyword'
			},
			optional_for_reports: {
				type: 'keyword'
			},
			use_category_for_lis: {
				type: 'integer'
			}
			
		}
    	
	end

	

	## @param[Hash] args : argument 
	def summary_row(args={})
		## those become hidden.
		## not totally absent.
		if args["root"] =~ /order/

			s = '
				<tr>
					<td>' + self.name + '</td>
					<td>' + self.quantity.to_s + '</td>
					<td>' + self.items.size.to_s + '</td>
			'

			if self.quantity > 0
				total_tubes_required = (self.quantity.to_f / 100.0).round(0)
				if self.items.size < total_tubes_required
					s  += '<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Click here and then click Add Items</div>'
				else
					s  += '<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Change Tube Barcodes</div>'
				end
			else
				s += '<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Edit</div>'
			end


			s += '</td></tr>'

			s
		
		else
			'
				<tr>
					<td>' + self.name + '</td>
					<td>' + self.quantity.to_s + '</td>
					<td>' + self.items.size.to_s + '</td>
					<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
				</tr>
			'
		end
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		'''
			<thead>
	          <tr>
	              <th>Name</th>
	              <th>Qunatity</th>
	              <th>Total Items</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	## if the root is an order, we don't want the add new button.
	def add_new_object(root,collection_name,scripts,readonly)
			 
		if root =~ /order/
			''
		else
			
			script_id = BSON::ObjectId.new.to_s

			script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
			
			scripts[script_id] = script_open

			scripts[script_id] +=  new_build_form(root + "[" + collection_name + "][]",readonly,"",scripts) + '</div></script>'
		
			element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"

			element
		end
	end


	## @param[Array] report: Diagnostics::Report array of all the reports that have been added to the order.
	## @return[nil]
	## @called_from : Concerns::OrderConcern::update_report_items
	## takes each item, in the category, takes its provided barcode, takes from self, the reports(optional/required) that this item is applicable to, gets that report from the incoming reports array, will delete the item if its not applicable to any basically will give an error. If a barcode is not applicable for a particular report, will add that in the cannot_be_added_to_reports, array for the item, and this is later used in the report#add_item def.
	def set_item_report_applicability(reports,order_id)
		report_ids = self.optional_for_reports + self.required_for_reports
		

		organization_id_to_report_hash = {}

		

		selected_reports = reports.select{|c| 
			

			if report_ids.include? c.id.to_s
				if organization_id_to_report_hash[c.currently_held_by_organization].blank?
					
					organization_id_to_report_hash[c.currently_held_by_organization] = [c.id.to_s]

				else

					organization_id_to_report_hash[c.currently_held_by_organization] << c.id.to_s

				end
				true
			else
				false
			end
		}

		#puts "selected reports are:"
		#puts selected_reports.to_s
		
		items_not_available_for_any_organization = []

		self.items.each do |it|
			
			if !it.use_code.blank?
				if it.code_matches?
					## in this case, we don't do any of the barcode level validations.
					organization_id_to_report_hash.keys.each do |org_id|
						it.applicable_to_report_ids << organization_id_to_report_hash[org_id]
					end
				else
					it.code_mismatch = true
				end

			else
				applicable = false

				organization_id_to_report_hash.keys.each do |org_id|

					#puts "doing org id: #{org_id}"
					res = it.get_item_details_from_barcode(org_id,self.name,organization_id_to_report_hash[org_id],applicable,organization_id_to_report_hash,order_id)
					#puts "applicable becomes:"
					#puts applicable.to_s
					unless res.blank?
						applicable = res if applicable.blank?
					end
				end

				it.not_applicable_to_any_reports = true if applicable == false
			end

			it.applicable_to_report_ids.flatten!

		end

	end

	def satisfied?
		mod = self.quantity % 100
		required_item_quantity = (self.quantity/100).to_i
		required_item_quantity += 1 if (mod > 0)
		self.items.size == required_item_quantity
	end

	def additional_required_items
		mod = self.quantity % 100
		required_item_quantity = (self.quantity/100).to_i
		required_item_quantity += 1 if (mod > 0)
		required_item_quantity - self.items.size
	end

end