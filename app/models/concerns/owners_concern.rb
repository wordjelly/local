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

		validate :created_user_has_role
		
		validate :organization_users_are_enrolled_with_organization

		attribute :public, Integer, mapping: {type: 'integer'}, default: Concerns::OwnersConcern::IS_PRIVATE
		### CHECKS THAT THERE IS A CREATED_USER, AND THAT IT HAS A ROLE.
		def created_user_has_role
			if self.created_by_user.blank?
				self.errors.add(:created_by_user,"There is no creating user")
			else
				if self.created_by_user.role.blank?
					self.errors.add(:created_by_user,"You don't have a role, please go to your profile link, and add a Role")
				end
			end
		end

		## CHECKS THAT IF THE ROLE IS OF AN ORGANIZATION, THEN THE USER IS VERIFIED, AS BELONGING TO IT.
		## this ensures that only verified organization users can interact with resources. 
		def organization_users_are_enrolled_with_organization
			unless self.created_by_user.role.blank?
				if self.created_by_user.is_an_organization_role?

					## what if he is the organization owner ?
					## is_organization_owner
					## belongs_to_organization
					if ((self.created_by_user.is_organization_owner?) || (self.created_by_user.belongs_to_organization?))


					else

						self.errors.add(:created_by_user,"You are currently not registered with an organization, Please join an organization or create an organization") if self.created_by_user.organization_id.blank?

						self.errors.add(:created_by_user,"You haven't yet been verified as belonging to your organization, Please request the organization owner to verify you") if self.created_by_user.verified_as_belonging_to_organization.blank?

					end

				end
			end
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
					unless document.created_by_user.organization_id.blank?
						unless document.created_by_user.verified_as_belonging_to_organization.blank?
							document.owner_ids << [document.created_by_user.organization_id]
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

end