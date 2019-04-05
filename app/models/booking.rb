require 'elasticsearch/persistence/model'
class Booking

	include Elasticsearch::Persistence::Model
	index_name "pathofast-bookings"
	
	attribute :status_id, String, mapping: {type: 'keyword'}
	attribute :count, Float, :default => 1
	attribute :priority, Float, :default => 0
	attribute :order_id, String, mapping: {type: 'keyword'}
	attribute :report_ids, Array, mapping: {type: 'keyword'}
	attribute :max_delay, Integer, :default => 3600
	
end	