module Concerns::StatusConcern

	extend ActiveSupport::Concern

	included do 
		
		attr_accessor :statuses
		attr_accessor :status_names

		after_find do |document|
			load_statuses
		end

		def load_statuses
			results = Status.search({
				sort: {
					created_at: {
						order: "desc"
					}
				},
				query: {
					term: {
						parent_ids: self.id.to_s
					}
				}
			})
			self.statuses = []
			self.statuses = results.response.hits.hits.map{|c|
				s = Status.new(c._source)
				s.id = c._id
				s
			}
			
		end

		
	end

end