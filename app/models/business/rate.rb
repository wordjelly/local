require 'elasticsearch/persistence/model'

class Business::Rate
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern
	UNIVERSAL_ORGANIZATION_ID = "*"
	YES = 1
	NO = 0

	
	attribute :for_organization_id, String, mapping: {type: 'keyword'}, default: Business::Rate::UNIVERSAL_ORGANIZATION_ID
	attribute :rate, Float
	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s
	attribute :patient_rate, Integer, mapping: {type: 'integer'}, default: NO
	
	def self.permitted_params
		[:id,:for_organization_id, :rate,:patient_rate]
	end

	def self.index_properties
		{
	    	for_organization_id: {
	    		type: 'keyword'
	    	},
	    	rate: {
	    		type: 'float'
	    	},
	    	name: {
	    		type: 'keyword'
	    	},
	    	patient_rate: {
	    		type: 'integer'
	    	}
		}
	end

	##########################################################
	##
	##
	## HELPERS 
	##
	##
	##########################################################
	def is_patient_rate?	
		self.patient_rate == YES
	end

	def is_default_rate?
		self.for_organization_id == UNIVERSAL_ORGANIZATION_ID
	end
	##########################################################
	##
	##
	##
	##
	##
	##########################################################


	def summary_row(args={})
		"
			<tr>
				<td>#{self.for_organization_id}</td>
				<td>#{self.rate}</td>
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
	              <th>For Organization Id</th>
	              <th>Rate</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		"
	end

end