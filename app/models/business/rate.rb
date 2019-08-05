require 'elasticsearch/persistence/model'

class Business::Rate
	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	#include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	UNIVERSAL_ORGANIZATION_ID = "*"

	## the id of the organization for which this rate is being set.
	## if it is set to 
	attribute :for_organization_id, String, mapping: {type: 'keyword'}, default: Business::Rate::UNIVERSAL_ORGANIZATION_ID
	attribute :rate, Float
	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s

	def self.permitted_params
		[:for_organization_id, :rate]
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
	    	}
		}
	end

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
	def summary_table_headers
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