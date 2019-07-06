module Concerns::Schedule::BookingConcern
	extend ActiveSupport::Concern

  	included do

  	end

  	## @param[Hash] args: arguments to pass for making the different blocks
  	## required arguments include?
  	##
  	def build_blocks(args)
		blocks = []
		# prospective_blocks(status,current_minute,employee_id)
		blocks << Schedule::Block.prospective_blocks(args)
		blocks << Schedule::Block.retrospective_blocks(args)		
  	end

end