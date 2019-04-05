require 'elasticsearch/persistence/model'
class Employee

	include Elasticsearch::Persistence::Model
	index_name "pathofast-employees"
	
	attribute :status_ids, Array, :default => []
	attribute :booked_status_id, Integer, :default => -1
	attribute :booked_count, Integer, :default => 0
	
end