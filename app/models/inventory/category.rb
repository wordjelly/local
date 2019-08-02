require 'elasticsearch/persistence/model'

class Inventory::Category

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	#include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern

	attribute :name, String, mapping: {type: 'keyword'}
	## this is a percentage.
	attribute :quantity, Float, mapping: {type: 'float'}, default: 100
	## these will be the items added.
	## so i had added it here.
	attribute :items, Array[Inventory::Item]
	attribute :required_for_reports, Array, mapping: {type: 'keyword'}, default: []
	attribute :optional_for_reports , Array, mapping: {type: 'keyword'}, default: []

	def self.permitted_params
		[
			:quantity,
			:name,
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
			}
			
		}
    	
	end

	def summary_row
		'
			<tr>
				<td>' + self.name + '</td>
				<td>' + self.quantity.to_s + '</td>
				<td>' + self.items.size.to_s + '</td>
				<td><div class="edit_nested_object">Edit</div></td>
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
	              <th>Qunatity</th>
	              <th>Total Items</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end


end