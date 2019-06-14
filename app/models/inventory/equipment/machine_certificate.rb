require 'elasticsearch/persistence/model'

class Inventory::Equipment::MachineCertificate

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern

	index_name "pathofast-inventory-equipment-machine-certificates"
	document_type "inventory/equipment/machine-certificate"	
	CERTIFICATE_TYPES = ["IQ","OQ","PQ","Installation","Maintainance","Scrap"]

	attribute :machine_id, String, mapping: {type: 'keyword'}
	validates_presence_of :machine_id

	attribute :certificate_type, String, mapping: {type: 'keyword'}
	validates_presence_of :certificate_type

	attribute :issued_by, String, mapping: {type: 'keyword'}
	validates_presence_of :issued_by

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
	end

	## determine machine complaints.
	## determine the status of the machine based on complaint resolution.
	## we can have this at report level also.


	def self.permitted_params
		base = [
				:id,
				{:machine_certificate => 
					[
						:machine_id,
						:certificate_type,
						:issued_by
					]
				}
			]
		if defined? @permitted_params
			base[1][:machine_certificate] << @permitted_params
			base[1][:machine_certificate].flatten!
		end
		base
	end

	def fields_not_show_in_form
		["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","name"]		
	end


	def assign_id_from_name
		if self.id.blank?		
			unless self.machine_id.blank?
				unless self.certificate_type.blank?
					unless self.issued_by.blank?
						self.id = self.created_by_user.organization.name.to_s + "/" + self.class.name.to_s + "/" + self.machine_id.to_s + "-" + self.certificate_type.to_s + "-" + self.issued_by.to_s
						self.name = self.id
					end
				end
			end
		end
	end


end