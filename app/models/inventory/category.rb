require 'elasticsearch/persistence/model'

class Inventory::Category

	## embedded in requirement.
	## embeds many items.

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::TransferConcern
	include Concerns::MissingMethodConcern

	## inside this is item.
	## simply.
	attribute :items, Array[Hash]

end