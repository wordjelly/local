require 'elasticsearch/persistence/model'
class Business::Order

	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-business-orders"
	document_type "business/order"
	include Concerns::OrderConcern
	include Concerns::PdfConcern


end