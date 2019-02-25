require 'elasticsearch/persistence/model'

class ItemGroup

	include Elasticsearch::Persistence::Model

	index_name "pathofast-item-groups"

	attribute :item_ids, Array

	attr_accessor :item_id

	attr_accessor :item_id_action

	attribute :barcode, String

end