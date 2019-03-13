module Concerns::StatusConcern

	extend ActiveSupport::Concern

	included do 
		
		attr_accessor :statuses

		after_find do |document|
			document.load_statuses
		end

		def load_statuses
			self.statuses = Status.search({
				query: {
					parent_id: self.id.to_s
				}
			})
		end

	end

end