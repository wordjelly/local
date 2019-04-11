require 'elasticsearch/persistence/model'
class OrderLog

	include Elasticsearch::Persistence::Model

	index_name "pathofast-orderlogs"

	attribute :log_time, Date

	attribute :description, String, mapping: {type: 'keyword'}

	attribute :report_ids, Array, mapping: {type: 'keyword'}

	attribute :order_start_time, Date

	## this is never directly committed.
	## it is embedded inside order

end