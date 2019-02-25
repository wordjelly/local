require 'elasticsearch/persistence/model'
class Employee

	include Elasticsearch::Persistence::Model
	index_name "pathofast-employees"
	
end