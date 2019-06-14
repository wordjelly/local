class OrganizationMember
	include Mongoid::Document
	embedded_in :user, class_name: "User"
	field :organization_id, type: String
	field :employee_role_id, type: String
	## if the organization is created by the given user
	## then this field will have the value "yes"
	field :created_by_this_user, type: String
	attr_accessor :membership_status

	CREATED_BY_THIS_USER = "yes"

	def set_membership_status(user_id)
		if self.organization_id
			unless self.created_by_this_user.blank?
				self.membership_status = Organization::USER_VERIFIED
			else
				organization = Organization.find(self.organization_id)
				puts "found the organization: #{organization.name}"
				organization.run_callbacks(:find)
				puts "the user id being queried is:"
				puts user_id
				puts "the organization user ids are:"
				puts organization.user_ids
				if organization.has_verified_user?(user_id)
					self.membership_status = Organization::USER_VERIFIED
					puts "the membership status was set to verified."
					puts self.membership_status
				elsif organization.has_rejected_user?(user_id)
					self.membership_status = Organization::USER_REJECTED
				elsif organization.has_user_pending_verification?(user_id)
					self.membership_status = Organization::USER_PENDING_VERIFICATION
				else
					
				end
			end
		end
	end


end	