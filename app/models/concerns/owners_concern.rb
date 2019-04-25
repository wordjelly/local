module Concerns::OwnersConcern

	extend ActiveSupport::Concern

	included do 

		attribute :owner_ids, Array, mapping: {type: 'keyword'}
		
		attr_accessor :created_by_user

		before_save do |document|
			if document.class.name == "Organization"
				## if the document is an organization.
				## set its owner id, as its own id.
				## basically anybody with that organization can edit it.
				document.id.to_s ||= document.name
				document.owner_ids ||= [document.id.to_s]
			else
				document.owner_ids << created_by_user.organization_ids unless created_by_user.blank?
			end
			document.owner_ids.flatten!
		end

	end

end