require 'elasticsearch/persistence/model'

class Barcode
	
	include Elasticsearch::Persistence::Model

	index_name "pathofast-barcodes"

end