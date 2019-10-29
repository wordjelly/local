require 'elasticsearch/persistence/model'

class Inventory::Equipment::Engineer

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
		include Concerns::CallbacksConcern


	index_name "pathofast-inventory-equipment-engineers"
	document_type "inventory/equipment/engineer"

	attribute :full_name, String, mapping: {type: 'keyword'}
	attribute :phone_number, String, mapping: {type: 'keyword'}


end