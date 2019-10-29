require 'elasticsearch/persistence/model'

class OrganizationSetting

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::EsBulkIndexConcern
	include Concerns::FormConcern
	include Concerns::MissingMethodConcern
	include Concerns::CallbacksConcern

	## so we have missing method.
	## and it should have triggered the nested
	## in the before validation.

	PREPAID = "pre_paid"
	POSTPAID = "post_paid"
	YES = "yes"
	NO = "no"
	PAYMENT_POLICIES = [PREPAID,POSTPAID]
	YES_NO = [YES,NO]
	
	attribute :name, String, mapping: {type: 'keyword'}

	attribute :for_organization_id, String, mapping: {type: 'keyword'}
	
	attribute :for_patient_id, String, mapping: {type: 'keyword'}

	attribute :payment_policy, String, mapping: {type: 'keyword'}, default: POSTPAID 
		
	attribute :accept_orders, String, mapping: {type: 'keyword'}, default: YES

	#################################################################
	##
	##
	## FORM SETTINGS
	##
	##
	#################################################################
	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","active"]
		}
	end

	def customizations(root)
		customizations = {}

		customizations["for_organization_id"] = "<div class='input-field'><input type='text' data-use-id='yes' data-autocomplete-type='for_organization_id' data-index-name='pathofast-organizations' name='" + (root + "[for_organization_id]") + "' /><label>For Organization Id</label></div>"

		customizations["for_patient_id"] = "<div class='input-field'><input type='text' data-use-id='yes' data-autocomplete-type='for_patient_id' data-index-name='pathofast-patients' name='" + (root + "[for_patient_id]") + "' /><label>For Patient Id</label></div>"

		customizations["payment_policy"] = "<div class='input-field'>" + (select_tag(root + "[payment_policy]",options_for_select(PAYMENT_POLICIES,(self.payment_policy || POSTPAID)))) + "<label>Choose Payment Policy</label></div>"

		customizations["accept_orders"] = "<div class='input-field'>" + (select_tag(root + "[accept_orders]",options_for_select(YES_NO,(self.accept_orders || YES)))) + "<label>Continue to Accept Orders From Them</label></div>"

		customizations
	end
	
	#################################################################
	##
	##
	## PERMITTED PARAMS
	##
	##
	#################################################################
	def self.permitted_params
		[
			:id,
			:name,
			:for_organization_id,
			:for_patient_id,
			:payment_policy,
			:accept_orders
		]
	end

	#################################################################
	##
	##
	## INDEX PROPERTIES.
	##
	##
	#################################################################
	def self.index_properties
		{
			:name => {
				:type => 'keyword',
				:fields => {
						:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
		      		}
				}
			},
			:for_organization_id => {
				:type => 'keyword'
			},
			:for_patient_id => {
				:type => 'keyword'
			},
			:payment_policy => {
				:type => 'keyword'
			},
			:accept_orders => {
				:type => 'keyword'
			}
		}
	end

	def summary_row(args={})
		"
			<tr>
				<td>Id</td>
				<td>#{self.for_organization_id}</td>
				<td>#{self.for_patient_id}</td>
				<td>#{self.payment_policy}</td>
				<td>#{self.accept_orders}</td>
				<td><div class='edit_nested_object' data-id='#{self.unique_id_for_form_divs}'>Edit</div></td>
			</tr>
		"
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		"
			<thead>
	          <tr>
	          	  <th>Id</th>
	              <th>For Organization Id</th>
	              <th>For Patient Id</th>
	              <th>Payment Policy</th>
	              <th>Accept Orders</th>
	          </tr>
	        </thead>
		"
	end


end