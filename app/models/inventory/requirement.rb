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
	
	index_name "pathofast-inventory-item-requirements"
	document_type "inventory/item-requirement"

	## the optionals
	## so what will the final thing look like.
	## it will be an array of requirements only.
	attribute :categories, Array[Hash]
	attribute :quantity, Integer	


end
