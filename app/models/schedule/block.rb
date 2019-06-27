require 'elasticsearch/persistence/model'
class Schedule::Block
	include Elasticsearch::Persistence::Model
	index_name "pathofast-schedule-bookings"
	document_type "schedule/booking"

	attribute :from_minute, Integer, mapping: {type: 'integer'}
	attribute :to_minute, Integer, mapping: {type: 'integer'}
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
			except: {
				type: 'integer'
			},
			employee_ids: {
				type: 'keyword'
			},
			remaining_capacity: {
				type: 'keyword'
			}
		}
	end

	def self.build_blocks_script(minute,status)
		
		if status.block_other_employees
		else
		end
	end

end