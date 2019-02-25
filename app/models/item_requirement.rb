require 'elasticsearch/persistence/model'
class ItemRequirement 
	
	include Elasticsearch::Persistence::Model

	index_name "pathofast-item-requirements"

	attribute :item_type, String
	
	attribute :optional, String
	
	attribute :amount, Float
	
	attribute :priority, Integer

	

end