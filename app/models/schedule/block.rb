require 'elasticsearch/persistence/model'
class Schedule::Block
	include Elasticsearch::Persistence::Model
	index_name "pathofast-schedule-bookings"
	document_type "schedule/booking"

	attribute :minutes, Array, mapping: {type: 'integer'}
	attribute :statuse_ids, Array, mapping: {type: 'keyword'}
	attribute :employee_ids, Array, mapping: {type: 'keyword'}
	attribute :remaining_capacity, Integer, mapping: {type: 'integer'}

	def self.index_properties
		{
			minutes: {
				type: 'integer'
			},
			status_ids: {
				type: 'keyword'
			},
			employee_ids: {
				type: 'keyword'
			},
			remaining_capacity: {
				type: 'keyword'
			}
		}
	end

end