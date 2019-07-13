require 'elasticsearch/persistence/model'
class Employee

	include Elasticsearch::Persistence::Model
	index_name "pathofast-employees"
	
	attribute :status_ids, Array, :default => []
	attribute :employee_id, String, mapping: {type: "keyword"}
	attribute :bookings_score, Float, :default => 0
	attribute :bookings, Array[Schedule::Booking]
	attribute :number, Integer
	attribute :id_minute, String, mapping: {type: 'keyword'}
	
end