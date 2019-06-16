class Requirement

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

	attribute :item_type_id, String, mapping: {type: 'keyword'}
	
	attribute :priority, Integer
	
	attribute :barcode, String, mapping: {type: 'keyword'}
	
	attribute :quantity, Integer	

end
