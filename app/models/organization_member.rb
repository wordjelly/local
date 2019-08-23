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
			puts "there is an organization id: #{self.organization_id}"
			organization = Organization.find(self.organization_id)
			organization.run_callbacks(:find)
			self.organization = organization
			puts "got an organization"
			unless self.created_by_this_user.blank?
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