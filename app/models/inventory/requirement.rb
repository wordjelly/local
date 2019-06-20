class Inventory::Requirement

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::MissingMethodConcern
	
	index_name "pathofast-inventory-requirements"
	document_type "inventory/requirement"

	attribute :categories, Array[Hash]
	attribute :name, String, mapping: {type: 'keyword'}

	def assign_id_from_name
		self.name = BSON::ObjectId.new.to_s
		self.id = self.name
	end

	def self.permitted_params
		[
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
