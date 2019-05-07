module Concerns::VersionedConcern

	extend ActiveSupport::Concern

	## how many changes to store in memory
	MAX_CHANGES = 10
	
	VERIFIED_OPTIONS = ["on","off"]
	
	VERIFIED = "on"
	
	REJECTED = "off"

	included do 

		@permitted_params = [:verified_by_user_ids, :rejected_by_user_ids]

		attribute :versions, Array[Hash]
		attribute :verified_by_user_ids, Array, mapping: {type: 'keyword'}
		attribute :rejected_by_user_ids, Array, mapping: {type: 'keyword'}

		mapping do 
			indexes :verified_by_user_ids, type: 'keyword'
			indexes :rejected_by_user_ids, type: 'keyword'
			indexes :verified, type: 'integer'
			indexes :versions, type: 'nested' do 
				indexes :attributes_string, type: 'keyword'
				indexes :control_doc_number, type: 'keyword'
			end
		end

		before_save do |document|
			document.test_version(document.versions.size - 1)
		end

	end

	def version_rejected?
		self.rejected_by_user_ids > 0
	end

	def version_accepted?(created_by_user)
		self.verified_by_user_ids.size >= created_by_user.organization.verifiers
	end

	def test_version(index)
		return if index < 0
		obj = self.new(JSON.parse(self.versions[index][:attributes_string]))
		if obj.version_rejected?
			test_version(index-=1)
		elsif obj.version_accepted?(self.created_by_user)
			self.apply_version(obj)
		end
	end

	def apply_version(obj)
		self.attributes.merge(obj.attributes)
	end

	
end