class OrganizationMember
	include Mongoid::Document
	embedded_in :user, class_name: "User"
	field :organization_id, type: String
	field :employee_role_id, type: String
	## if the organization is created by the given user
	## then this field will have the value "yes"
	field :created_by_this_user, type: String
	attr_accessor :membership_status
	attr_accessor :organization

	## so the organization member has an organization.

	CREATED_BY_THIS_USER = "yes"


	def set_membership_status(user_id)
		unless self.organization_id.blank?
			
			organization = nil

			if RequestStore.store[self.organization_id].blank?
				puts "cannot find organization: #{self.organization_id} in the request store"
				organization = Organization.find(self.organization_id)
				RequestStore.store[self.organization_id] = organization
			else
				organization = RequestStore.store[self.organization_id]
			end

			#organization = ((RequestStore.store[self.organization_id]) || Organization.find(self.organization_id))
			
			
			## so the secondary skip will be done here.
			## we don't want to trigger it again.
			organization.skip_load_created_by_user = true
			organization.run_callbacks(:find)
			RequestStore.store[self.organization_id].users_pending_approval ||= organization.users_pending_approval
			RequestStore.store[self.organization_id].employee_roles ||= organization.employee_roles
			RequestStore.store[self.organization_id].locations ||= organization.locations
			RequestStore.store[self.organization_id].representative_patient ||= organization.representative_patient
			RequestStore.store[self.organization_id].after_find_performed = true


			self.organization = organization
			unless self.created_by_this_user.blank?
				## if the organization member was created by the same user in which it is housed
				## otherwise we have a problem.
				## then it is directly verified.
				self.membership_status = Organization::USER_VERIFIED
			else	
				if organization.has_verified_user?(user_id)
					self.membership_status = Organization::USER_VERIFIED
				elsif organization.has_rejected_user?(user_id)
					self.membership_status = Organization::USER_REJECTED
				elsif organization.has_user_pending_verification?(user_id)
					self.membership_status = Organization::USER_PENDING_VERIFICATION
				else
					
				end
			end
		end
	end

	def as_json(options={})
		super(:methods => [:organizaiton,:membership_status])
	end

end	