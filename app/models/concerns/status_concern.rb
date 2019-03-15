module Concerns::StatusConcern

	extend ActiveSupport::Concern

	included do 
		
		attribute :status_ids, Array, mapping: {type: 'keyword'}
		attr_accessor :statuses
		attr_accessor :status_names

		after_find do |document|
			load_statuses
		end

		before_save do |document|
			document.status_ids.reject!{|c| c.blank?}
		end

		def load_statuses
			self.status_ids ||= []
			self.statuses = self.status_ids.map{|c|
				c = Status.find(c)
			}
			
		end

	end

end