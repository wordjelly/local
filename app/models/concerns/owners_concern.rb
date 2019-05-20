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
		
		attr_accessor :created_by_user

		## set in the create action in base_controller_concern
		## it is the created_by_user id.
		attribute :created_by_user_id

		validate :created_user_exists
			
		validate :organization_users_are_enrolled_with_organization, :unless => Proc.new{|c| (c.new_record? && c.class.name == "Organization")}

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

		## assign public roles by default.

		## CHECKS THAT IF THE ROLE IS OF AN ORGANIZATION, THEN THE USER IS VERIFIED, AS BELONGING TO IT.
		## this ensures that only verified organization users can interact with resources. 
		def organization_users_are_enrolled_with_organization
			
			## related to organization.
			## that means either he created an organization, or  
			if self.created_by_user.has_organization?
				if !self.created_by_user.owns_or_belongs_to_organization?
					self.errors.add(:created_by_user,"you have not yet been verified as belonging to this organization")
				end
			end

=begin
			unless self.created_by_user.owns_or_belongs_to_organization?
				#self.errors.add(:)
				self.errors.add(:created_by_user,"you need to ")
			end
			unless self.created_by_user.role.blank?
				if self.created_by_user.is_an_organization_role?

					puts "the role is an organization role."
					puts "is organization owner: #{self.created_by_user.is_organization_owner?}"
					puts "belongs to an organization: #{self.created_by_user.belongs_to_organization?}"
					if ((self.created_by_user.is_organization_owner?) || (self.created_by_user.belongs_to_organization?))


					else

						self.errors.add(:created_by_user,"You are currently not registered with an organization, Please join an organization or create an organization") if self.created_by_user.organization_id.blank?

						self.errors.add(:created_by_user,"You haven't yet been verified as belonging to your organization, Please request the organization owner to verify you") if self.created_by_user.verified_as_belonging_to_organization.blank?

					end

				end
			end
=end

		end

		before_save do |document|
			## when a document is being created
			## the created_by_user's id is added to it.
			## secondly, the created_by_user's organization id is
			## also added, if the organization has verified the user
			if document.owner_ids.blank?
				unless document.created_by_user.blank?
					## in case the user is creating an organiztion,
					## it will not have an organization id itself.
					## since the organiztion has not yet even been created
					## that's why we started the system of adding the creating users id
					## to the owner ids of any document it creates. 
					## 
					document.owner_ids = [document.created_by_user.id.to_s]
					unless document.created_by_user.organization.blank?
						unless document.created_by_user.verified_as_belonging_to_organization.blank?
							document.owner_ids << [document.created_by_user.organization.id.to_s]
						end
					end
				end
				## if the document is an organization, its own id 
				## is added as an owner
				## because when users belonging to this organization
				## try to access it, they will be using their organization id 
				## in the authorization query.
				if document.class.name == "Organization"
					if document.owner_ids.blank?
						document.owner_ids = [document.id.to_s]
					end
				end
			end
		
			document.owner_ids.flatten!
		
		end

	end

	## an item cannot be added to a transaction unless that transaction has received some items.
	## secondly it has to know how many items were created from 
	## that transaction.
	## 

	## so the transfer adds the item as an owner.
	## now we have to decide what all can be modified.
	## we can additionally define, what the original
	## creator's organization can modify, 
	## and what other organizations can modify/.
	## this can be defined in the permissions.
	def add_owner(user_id)
		begin
			u = User.find(user_id)
			self.owner_ids << u.organization.id.to_s
			self.save
		rescue
			self.errors.add(:owner_ids, "could not add the recipient to the owner ids of the object #owners_concern.rb")
		end
	end

end