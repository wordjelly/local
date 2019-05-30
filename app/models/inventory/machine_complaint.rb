require 'elasticsearch/persistence/model'

class Inventory::MachineComplaint

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-inventory-machines"
	document_type "inventory/machine"

	attribute :machine_id, String, mapping: {type: 'keyword'}
	attribute :complaint_description, String, mapping: {type: 'keyword'}
	attribute :call_logged, String, mapping: {type: 'keyword'}
	attribute :call_log_number, String, mapping: {type: 'keyword'}
	attribute :engineer_assigned_to, String, mapping: {type: 'keyword'}


end