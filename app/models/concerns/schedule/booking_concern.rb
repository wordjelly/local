module Concerns::Schedule::BookingConcern
	extend ActiveSupport::Concern

  	included do

  	end

  	## @param[Hash] args: arguments to pass for making the different blocks
  	## required arguments include?
  	##
  	def build_blocks(args)
		  
		  # prospective_blocks(status,current_minute,employee_id)
		  self.blocks << Schedule::Block.prospective_blocks(args).flatten
		  self.blocks << Schedule::Block.retrospective_blocks(args).flatten
  	  self.blocks.flatten!
    end

end