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

	attribute :name, String, mapping: {type: 'keyword'}
	attribute :quantity, Float, mapping: {type: 'float'}
	attribute :items, Array[Hash]
	attribute :required_for_reports, Array, mapping: {type: 'keyword'}
	attribute :optional_for_reports , Array, mapping: {type: 'keyword'}

	attr_accessor :optional_for_reports

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


end