require 'elasticsearch/persistence/model'

class Inventory::Equipment::Machine

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


	index_name "pathofast-inventory-equipment-machines"
	document_type "inventory/equipment/machine"

	attribute :serial_number, String, mapping: {type: 'keyword'}
	validates_presence_of :serial_number

	attribute :model, String, mapping: {type: 'keyword'}
	validates_presence_of :serial_number

	attribute :machine_classification, String , mapping: {type: 'keyword'}
	validates_presence_of :serial_number

	attribute :description, String, mapping: {type: 'keyword'}

	attribute :asset_code, String, mapping: {type: 'keyword'}

	attribute :service_engineers, Array[Inventory::Equipment::Engineer]
	
	attribute :sales_engineers, Array[Inventory::Equipment::Engineer]
	
	attribute :date_of_installation, Date, mapping: {type: 'date', format: "yyyy-MM-dd"}
	validates_presence_of :serial_number

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
	    indexes :service_engineers, type: 'nested' do 
	    	indexes :full_name, type: 'keyword'
	    	indexes :phone_number, type: 'keyword'
	    end
	    indexes :sales_engineers, type: 'nested' do 
	    	indexes :full_name, type: 'keyword'
	    	indexes :phone_number, type: 'keyword'
	    end
	end

	## determine machine complaints.
	## determine the status of the machine based on complaint resolution.
	## we can have this at report level also.


	def self.permitted_params
		base = [
				:id,
				{:machine => 
					[
						:date_of_installation,
						:serial_number,
						:model,
						:machine_classification,
						:description,	
						{
							:service_engineers => [
								:full_name,
								:phone_number
							]
						},
						{
							:sales_engineers => [
								:full_name,
								:phone_number
							]
						}
					]
				}
			]
		if defined? @permitted_params
			base[1][:machine] << @permitted_params
			base[1][:machine].flatten!
		end
		base
	end

	def fields_not_show_in_form
		["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","name"]		
	end


	def assign_id_from_name
		if self.id.blank?		
			unless self.model.blank? 
				unless self.serial_number.blank?
					unless self.machine_classification.blank?
						self.name = self.machine_classification + "-" + self.model + "-" + self.serial_number
					end
				end
			end	
			self.id = self.created_by_user.organization.name.to_s + "-" + self.class.name.to_s + "-" + self.name 
			self.asset_code = self.id
		end
	end

	before_save do |document|
		document.cascade_id_generation(nil)
	end


end