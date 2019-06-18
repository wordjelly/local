require 'elasticsearch/persistence/model'

class Business::Payment

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern

	attribute :amount, Float, mapping: {type: 'float'}

end