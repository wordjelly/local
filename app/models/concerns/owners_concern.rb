module Concerns::OwnersConcern

	extend ActiveSupport::Concern

	## 1 -> public
	## 0 -> not public.
	## set_model in base_controller_concern, adds an or clause as public -> 1, for every query.
	## so that if a model is there, where the requesting user is not the creating user, or belonging to the creating organization, it can still see this record, if this record is public.
	## this will also help at search time, the same clause can be used.
	PUBLIC_OPTIONS = [0,1]

	IS_PUBLIC = 1

	IS_PRIVATE = 0

	included do 

		attribute :owner_ids, Array, mapping: {type: 'keyword'}
		
		## skip owners validations.
		attr_accessor :skip_owners_validations

		attr_accessor :created_by_user

		## the organization is loaded from the currently_held_by_organization			
		## its 
		attr_accessor :organization

		## set in the create action in base_controller_concern
		## it is the created_by_user id.
		attribute :created_by_user_id

		## i think that will be the last organization.
		## once an item is 
		## we have to use this from the report.
		## to check where that organization is in the owner ids.
		## and barcode is that.
		## whether it is valid or not.
		## that's the way.
		## is nested has to be set.
		## only then can we know.
		## so how to pass this downwards to the item ?
		## 
		attribute :currently_held_by_organization, String, mapping: {type: 'keyword'}

		validate :created_user_exists, :unless => Proc.new{|c| c.skip_owners_validations.blank?}
			
		validate :organization_users_are_enrolled_with_organization, :unless => Proc.new{|c| (c.new_record? && c.class.name == "Organization") || (c.skip_owners_validations.blank?)}

		attribute :public, Integer, mapping: {type: 'integer'}, default: Concerns::OwnersConcern::IS_PRIVATE

		## for what?
		## it could be creating an organization itself.
		## why does it need to have a role?
		### CHECKS THAT THERE IS A CREATED_USER, AND THAT IT HAS A ROLE.
		def created_user_exists
			if self.created_by_user.blank?
				self.errors.add(:created_by_user,"There is no creating user")
			#else
			#	if self.created_by_user.role.blank?
			#		self.errors.add(:created_by_user,"You don't have a role, please go to your profile link, and add a Role")
			#	end
			end
		end

		## depending on the context.
		## we have to show custom options.
		## make it easier to add more reprots
		## see why there is duplication of the required reports
		## and change the name of categ
		## assign public roles by default.
		## CHECKS THAT IF THE ROLE IS OF AN ORGANIZATION, THEN THE USER IS VERIFIED, AS BELONGING TO IT.
		## this ensures that only verified organization users can interact with resources. 
		def organization_users_are_enrolled_with_organization
			
			## related to organization.
			## that means either he created an organization, or 
			#puts "failing here --------"
			#puts self.class.name.to_s 
			#puts "the self created by user is:"
			#puts self.created_by_user
			#puts "the self organization is:"
			#puts self.created_by_user.organization.to_s
			#puts "class is: #{self.class.name}"
			#puts "skip validation: #{self.skip_owners_validations}"
			if !self.created_by_user.has_organization?
				self.errors.add(:created_by_user,"you have not yet been verified as belonging to this organization")
			end

		end

		def add_owner_ids
			if self.owner_ids.blank?
				unless self.created_by_user.blank?
					## in case the user is creating an organiztion,
					## it will not have an organization id itself.
					## since the organiztion has not yet even been created
					## that's why we started the system of adding the creating users id
					## to the owner ids of any document it creates. 
					## this part will change a bit.
					self.owner_ids = [self.created_by_user.id.to_s]
					unless self.created_by_user.organization.blank?
						
						self.owner_ids << [self.created_by_user.organization.id.to_s]
						self.currently_held_by_organization = created_by_user.organization.id.to_s
						
					end
				end
				## if the document is an organization, its own id 
				## is added as an owner
				## because when users belonging to this organization
				## try to access it, they will be using their organization id 
				## in the authorization query.
				## okay this is understandable.
				if self.class.name == "Organization"
					if self.owner_ids.blank?
						self.owner_ids << self.id.to_s
					end
				end
			end
		
			self.owner_ids.flatten!
		end


		## this also should be methodized to enable overrides.
		before_save do |document|
			document.add_owner_ids
		end


		after_find do |document|
			unless document.class.name == "Organization"
				unless document.currently_held_by_organization.blank?
					document.organization = Organization.find(document.currently_held_by_organization)
				end
			end
		end

	end

	## an item cannot be added to a transaction unless that transaction has received some items.
	## secondly it has to know how many items were created from 
	## that transaction.
	## so the transfer adds the item as an owner.
	## now we have to decide what all can be modified.
	## we can additionally define, what the original
	## creator's organization can modify, 
	## and what other organizations can modify/.
	## this can be defined in the permissions.
	## refactor is completed.
	def add_owner(user_id)
		begin
			u = User.find(user_id)
			self.owner_ids << u.organization.id.to_s
			self.save
		rescue
			self.errors.add(:owner_ids, "could not add the recipient to the owner ids of the object #owners_concern.rb")
		end
	end

	## whether to show the public form or not.
	## @return[Boolean] true/false : if we have to show the form selection 
	## for visibility.
	def show_visibility_selection
		false
	end



end