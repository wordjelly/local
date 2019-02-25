module Concerns::Reports::CycleConcern

	extend ActiveSupport::Concern

	included do 
		attribute :stage, String
	end


	def notify

	end


	def move_forward

	end

end