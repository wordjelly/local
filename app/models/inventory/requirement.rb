class Inventory::Requirement

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::BarcodeConcern
	include Concerns::ImageLoadConcern
	#include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	
	index_name "pathofast-inventory-requirements"
	document_type "inventory/requirement"

	attribute :categories, Array[Inventory::Category]
	attribute :name, String, mapping: {type: 'keyword'}


	def self.permitted_params
		[
			:name,
			:barcode,
			:priority,
			{
				:categories => Inventory::Category.permitted_params
			}
		]
	end

	def self.index_properties
		
		{
	    	categories: {
	    		type: 'nested',
	    		properties: Inventory::Category.index_properties
	    	}
	    }

	end

	def summary_row(args={})
		'
			<tr>
				<td>' + self.name + '</td>
				<td>' + self.categories.size.to_s + '</td>
				<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
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
	              <th>Total Categories</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end


end
