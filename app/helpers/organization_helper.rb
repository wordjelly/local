module OrganizationHelper

	def show_logo_change_message?(organization)
		return false if organization.images.blank?
		if organization.images.size == 0
			true if organization.logo_url == Organization::DEFAULT_LOGO_URL
		end
	end

end