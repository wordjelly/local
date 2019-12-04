=begin
Sets the id of the document to its name.
Ensures that a name is present.
Ensures that the name does not exceed 100 characters in length
=end
module Concerns::NameIdConcern
	extend ActiveSupport::Concern
	included do 
		validates_presence_of :name
		validates_length_of :name, :maximum => 500
	end
	
	## called from create action of base_controller_concern
	## @called_from : cascade_id_generation(organization_id), in missing_method_concern.rb, and that is inturn called before_save, in all top level objects, so it is no longer done from the controller
	## this is because nested objects may be added or removed, in the update controller actions also. 
	## so do it before save in all the top level models
	## like 
	## report, order, patient, and the inventory stuff
	## and update that in the controller tests.
	## @param[String] organization_id
	def assign_id_from_name(organization_id)
		#if self.class.name.to_s =~ /receipt/i
		#	puts "came to assign id with name: with receipt"
		#end
		#puts "Came to assign id from name with class------------- #{self.class.name}"
		#puts "the id is: #{self.id.to_s}"
		if self.id.blank?
			#puts "id is blank."
			#puts "name is blank? #{self.name.blank?}"
			if self.name.blank?
				self.name = BSON::ObjectId.new.to_s
			end
			#self.name ||= BSON::ObjectId.new.to_s
			#puts "name becomes: #{self.name}"
			unless self.name.blank?
				if organization_id.blank?	
					## this will happen for organization.		
					self.id = (BSON::ObjectId.new.to_s + "-" + self.name)
				else
					self.id = organization_id + "-" + self.name
				end
			end
			#puts "id becomes: #{self.id.to_s}"
		end
		#if self.class.name.to_s =~ /receipt/i
		#	puts "id becomes: #{self.id.to_s}"
		#end
	end

end