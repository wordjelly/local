require 'elasticsearch/persistence/model'

class Business::Rate
	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	UNIVERSAL_ORGANIZATION_ID = "*"

	## the id of the organization for which this rate is being set.
	## if it is set to 
	attribute :for_organization_id, String, mapping: {type: 'keyword'}, default: Business::Rate::UNIVERSAL_ORGANIZATION_ID
	attribute :rate, Float

	def self.permitted_params
		[:for_organization_id, :rate]
	end

	def self.index_properties
		{
	    	for_organization_id: {
	    		type: 'keyword'
	    	},
	    	rate: {
	    		type: 'float'
	    	}
		}
	end

end