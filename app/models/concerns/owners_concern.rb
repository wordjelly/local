module Concerns::OwnersConcern

	extend ActiveSupport::Concern

	included do 

		attribute :owner_ids, Array, mapping: {type: 'keyword'}
		
		attr_accessor :created_by_user

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