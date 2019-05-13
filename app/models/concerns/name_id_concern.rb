=begin
Sets the id of the document to its name.
Ensures that a name is present.
Ensures that the name does not exceed 100 characters in length
=end
module Concerns::NameIdConcern
	extend ActiveSupport::Concern
	included do 
		validates_presence_of :name
		validates_length_of :name, :maximum => 100
	end

	## called from create action of base_controller_concern
	def assign_id_from_name
		if self.id.blank?			
			self.id = self.name 
		end
	end

end