module OrganizationHelper

	def show_logo_change_message?(organization)
		if organization.images.size == 0
			true if organization.logo_url == Organization::DEFAULT_LOGO_URL
		end
	end

end