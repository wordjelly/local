require 'elasticsearch/persistence/model'

class Business::Payment

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern
	include Concerns::FormConcern

	attribute :amount, Float, mapping: {type: 'float'}

	def self.permitted_params
		[:amount]
	end	

	def self.index_properties
		{
			amount: {
				type: 'float'
			}
		}
	end

end