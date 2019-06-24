require 'elasticsearch/persistence/model'
class Schedule::Booking

	include Elasticsearch::Persistence::Model
	index_name "pathofast-schedule-blocks"
	document_type "schedule/block"

	
	attribute :status_id, String, mapping: {type: 'keyword'}
	attribute :count, Float, :default => 1
	attribute :priority, Float, :default => 0
	attribute :order_id, String, mapping: {type: 'keyword'}
	attribute :report_ids, Array, mapping: {type: 'keyword'}
	attribute :max_delay, Integer, :default => 3600
	attribute :tubes, Array, mapping: {type: 'keyword'}
	attribute :blocks, Array[Schedule::Block]

	def self.index_properties
		{
			status_id: {
				type: 'keyword'
			},
			count: {
				type: 'integer'
			},
			priority: {
				type: 'float'
			},
			order_id: {
				type: 'keyword'
			},
			report_ids: {
				type: 'keyword'
			},
			max_delay: {
				type: 'keyword'
			},
			tubes: {
				type: 'keyword'
			},
			blocks: {
				type: 'nested',
				properties: Schedule::Block.index_properties
			}
		}
	end
	
end	