module Concerns::OrganizationConcern
	## this is only meant to be used with user.
	## this is not meant to be used anywhere else.
	extend ActiveSupport::Concern

	included do 

		field :organization_id, type: String

		field :verified_as_belonging_to_organization, type: Boolean, :default => false

		attr_accessor :organization

		after_find do |document|
			unless document.organization_id.blank?
				## search for an organization with this id,
				## that has this user in the user_ids
				## which is only possible if he was verified.
				search_results = Organization.search({
					query: {
						bool: {
							must: [
								{
									term: {
										user_ids: self.id.to_s
									}
								},
								{
									ids: {
										values: self.organization_id.to_s
									}	
								}
							]
						}
					}
				})

				unless search_results.response.hits.hits.blank?
					
					self.organization = Organization.new(search_results.response.hits.hits.first["_source"])
					#self.organization.id = search_results.response.hits.hits.first["_id"]

				end

			end
		end
	end

	def get_organization_name
		return ENV["DEFAULT_LAB_NAME"] if self.organization.blank?
		return self.organization.name
	end

	def get_organization_phone_number
		return ENV["DEFAULT_LAB_PHONE"] if self.organization.blank?
		return self.organization.phone_number
	end

	def get_organization_address
		return ENV["DEFAULT_LAB_ADDRESS"] if self.organization.blank?
		return self.organization.address
	end

	def get_organization_logo_url
		return Organization::DEFAULT_LOGO_URL if self.organization.blank?
		return self.organization.logo_url
	end

end