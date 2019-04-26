=begin
Sets the id of the document to its name.
Ensures that a name is present.
Ensures that the name does not exceed 100 characters in length
=end
module Concerns::NameIdConcern
	extend ActiveSupport::Concern
	included do 
		before_save do |document|
			#puts "came to the name id concern"
			if document.id.blank?
				#puts "the current id is blank"
				document.id = document.name 
				#puts "the id becomes: #{document.id}"
			end
		end
		validates_presence_of :name
		validates_length_of :name, :maximum => 100
	end
end