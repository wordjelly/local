module Concerns::VersionedConcern

	extend ActiveSupport::Concern

	## how many changes to store in memory
	MAX_CHANGES = 10
	
	VERIFIED_OPTIONS = ["on","off"]
	
	VERIFIED = "on"
	
	REJECTED = "off"

	included do 

		@permitted_params = [{:verified_by_user_ids => []}, {:rejected_by_user_ids => []}]

		attribute :versions, Array[Hash]
		attribute :verified_by_user_ids, Array, mapping: {type: 'keyword'}, :default => []
		attribute :rejected_by_user_ids, Array, mapping: {type: 'keyword'}, :default => []
		attribute :active, Integer, mapping: {type: 'integer'}, default: 0

		mapping do 
			indexes :verified_by_user_ids, type: 'keyword'
			indexes :rejected_by_user_ids, type: 'keyword'
			indexes :active, type: 'integer'
			indexes :versions, type: 'nested' do 
				indexes :attributes_string, type: 'keyword'
				indexes :control_doc_number, type: 'keyword'
			end
		end

		before_save do |document|
			## so while creating it wont do this.
			## then update will create one more version
			## and it will execute this.
			unless document.versions.size <= 1
				document.test_version(document.versions.size - 1)
			end
		end

	end

	def version_rejected?
		self.rejected_by_user_ids.size > 0
	end

	def version_verified?(created_by_user)
		self.verified_by_user_ids.size >= created_by_user.organization.verifiers
	end

	## so they send you a serum aliquot -> and you have a 

	def test_version(index)
		obj = self.class.new(JSON.parse(Version.new(self.versions[index]).attributes_string))
		if index == 0
			self.apply_version(obj)
			self.active = 0
		else
			if obj.version_rejected?
				test_version(index-=1)
			elsif obj.version_verified?(self.created_by_user)
				self.apply_version(obj)
				self.active = 1
			end
		end
	end

	def apply_version(obj)
		self.attributes.merge(obj.attributes)
	end

	
	## so if we have some acceptors.
	## now we make some new changes.
	## now who are the acceptors ?
	## 

	#########################################################3
	##
	## METHODS TO CHECK IF ACCEPTED/REJECTED HAS CHANGED, AND IF YES THEN BY ONLY THE CURRENT USER'S ID OR WHAT
	##
	#########################################################
	def verified_user_ids_changed?(new_verified_by_user_ids)
		puts "the self verified by user ids are:"
		puts self.verified_by_user_ids.to_s

		puts "the new verifeid by user ids are"
		puts new_verified_by_user_ids.to_s
		## it has to send what was already there.
		new_verified_by_user_ids ||= []

		(self.verified_by_user_ids - new_verified_by_user_ids | new_verified_by_user_ids - self.verified_by_user_ids) != []

	end

	def rejected_user_ids_changed?(new_rejected_by_user_ids)

		#puts "self rejected by user ids:"
		#puts self.rejected_by_user_ids.to_s

		#puts "new rejected by user ids"
		#puts new_rejected_by_user_ids.to_s

		#puts "---------------------------"
		if new_rejected_by_user_ids.blank?
			new_rejected_by_user_ids = []
		end

		(self.rejected_by_user_ids - new_rejected_by_user_ids | new_rejected_by_user_ids - self.rejected_by_user_ids) != []

	end
	
	def verified_or_rejected?
		return false if self.versions.blank?
		#puts "the self versions are:"
		#puts self.versions.to_s
		#puts self.versions[-1]
		## so these are coming as strings.
		## we can deep_symbolize.
		v = Version.new(self.versions[-1])
		obj = self.class.new(JSON.parse(v.attributes_string))
		obj.version_rejected? || obj.version_verified?(self.created_by_user)
	end

	## if a verified has increased, it will check that these attributes are the same.
	## helps to ensure that two people have entered the same value, for purpose of getting value entry cross checked.
	## for eg:
	## although parameters other than verified_user_ids and rejected_user_ids are not merged into version updates, if they have changed, we still have these other attributes coming in, and if a user is verifying a versino, we can force them to send in one of these parameters, to ensure that it is the same.
	## like a password to verify the version.
	def non_tamperables
		[]
	end

end