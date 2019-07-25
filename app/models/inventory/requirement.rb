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


end
