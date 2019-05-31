require 'elasticsearch/persistence/model'

class Inventory::Machine

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

	## should be organization/location/class/

	attribute :serial_number, String, mapping: {type: 'keyword'}
	attribute :model, String, mapping: {type: 'keyword'}
	attribute :machine_classification, String , mapping: {type: 'keyword'}
	attribute :description, String, mapping: {type: 'keyword'}
	attribute :asset_code, String, mapping: {type: 'keyword'}
	attribute :service_engineers, Array[Hash]
	attribute :sales_engineers, Array[Hash]
	attribute :date_of_installation, Date, mapping: {type: 'date', format: "yyyy-MM-dd"}
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
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		base
	end

end