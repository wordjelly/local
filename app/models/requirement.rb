require 'elasticsearch/persistence/model'
class Requirement

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	#include Concerns::VersionedConcern
	
	attribute :item_category, String, mapping: {type: 'keyword'}
	attribute :item_type_id, String, mapping: {type: 'keyword'}

end