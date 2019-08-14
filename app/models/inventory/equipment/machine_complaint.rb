require 'elasticsearch/persistence/model'

class Inventory::Equipment::MachineComplaint

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern

	index_name "pathofast-equipment-inventory-machine-complaints"
	document_type "inventory/equipment/machine-complaint"

	attribute :machine_id, String, mapping: {type: 'keyword'}
	attribute :complaint_description, String, mapping: {type: 'keyword'}
	CALL_LOGGED_OPTIONS = ["YES","NO"]
	attribute :call_logged, String, mapping: {type: 'keyword'}
	## add an image to that particular certificate.
	attribute :call_log_number, String, mapping: {type: 'keyword'}
	attribute :engineer_assigned_to, String, mapping: {type: 'keyword'}
	attribute :solutions, Array[Inventory::Equipment::Solution]
	attribute :name, String, mapping: {type: 'keyword'}

	mapping do
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"
	    indexes :solutions, type: 'nested' do 
	    	indexes :machine_complaint_id, type: 'keyword'
	    	indexes :suggested_action, type: 'text'
	    	indexes :feedback, type: 'text'
	    end
	end

	def self.permitted_params
		base = [
				:id,
				{:machine_complaint => 
					[
						:machine_id,
						:complaint_description,
						:call_logged,
						:call_log_number,
						:engineer_assigned_to,
						{
							:solutions => [
								:machine_complaint_id,
								:suggested_action,
								:feedback
							]
						}
					]
				}
			]
		if defined? @permitted_params
			base[1][:machine_complaint] << @permitted_params
			base[1][:machine_complaint].flatten!
		end
		base
	end

	def fields_not_show_in_form
		["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","name","barcode"]		
	end


	def assign_id_from_name
		if self.id.blank?
			self.id = self.created_by_user.organization.name.to_s + "-" + self.class.name.to_s + "-" + self.machine_id.to_s + "-" + BSON::ObjectId.new.to_s
			self.name = self.id.to_s
		end
	end

	before_save do |document|
		document.cascade_id_generation(nil)
	end

end