module Concerns::StatusConcern

	extend ActiveSupport::Concern

	included do 
		
		attribute :status_ids, Array
		attr_accessor :statuses
		attr_accessor :status_id

		after_find do |document|
			load_statuses
		end

		def load_statuses
			self.status_ids ||= []
			self.statuses = self.status_ids.map{|c|
				c = Status.find(c)
			}
			
		end

	end

end