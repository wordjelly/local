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

	## each has embedded items inside them.
	## multiple.
	## do we write that here or what ?
	
	attribute :categories, Array[Hash]
	
	attribute :priority, Integer
	
	attribute :barcode, String, mapping: {type: 'keyword'}
	
	attribute :quantity, Integer	

	attribute :local_item_group_id, String, mapping: {type: 'keyword'}

	attribute :local_item_id, String, mapping: {type: 'keyword'}

	

end
