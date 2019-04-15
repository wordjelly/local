module Concerns::OwnersConcern

	extend ActiveSupport::Concern

	included do 

		attribute :owner_ids, Array, mapping: {type: 'keyword'}
		attr_accessor :created_by_user

		before_save do |document|
			document.owner_ids << created_by_user.organization_ids
			document.owner_ids.flatten!
		end

	end


end