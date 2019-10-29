require 'elasticsearch/persistence/model'

class Inventory::Equipment::Solution

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	#include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
		include Concerns::CallbacksConcern


	index_name "pathofast-equipment-inventory-solutions"
	
	document_type "inventory/equipment/solution"

	attribute :machine_complaint_id, String, mapping: {type: 'keyword'}

	attribute :suggested_action, String, mapping: {type: 'text'}

	attribute :feedback, String, mapping: {type: 'text'}


	def fields_not_show_in_form
		["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","name"]		
	end

end