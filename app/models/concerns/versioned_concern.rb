module Concerns::VersionedConcern

	extend ActiveSupport::Concern

	## how many changes to store in memory
	MAX_CHANGES = 10
	
	VERIFIED_OPTIONS = ["on","off"]
	
	VERIFIED = "on"
	
	REJECTED = "off"

	included do 

		attribute :versions, Array[Hash]

		mapping do 
			indexes :versions, type: 'nested' do 
				indexes :attributes_string, type: 'keyword'
				indexes :verified_by_users, type: 'keyword'
				indexes :verified, type: 'keyword'
				indexes :verification_time, type: 'date'
				indexes :creation_time, type: 'date'
			end
		end

		validate :last_version_adjudicated?

		## looking for a class variable called object params.
		## if it is there, otherwise will define it.
		## this can be read finally in the permitted params def.
		## lets put this in normal range and see.
		if defined? @permitted_params
			@permitted_params.merge([:versions => {:attributes_string, {:verified_by_users => []}, :verified, :verification_time, :creation_time}])
		else
			@permitted_params = [:versions => {:attributes_string, {:verified_by_users => []}, :verified, :verification_time, :creation_time}]
		end

	end


	def last_version_adjudicated?
		unless self.versions.blank?
			if self.versions[-1][:verified].blank?
				self.errors.add(:versions,"the last version of this document has to either be VERIFIED or REJECTED before further changes can be made")
			end
		end
	end

	before_save do |document|

		## we dont permit verification time.
		## if the last version has come in as verified 1
		## then we set the verified time as now.
		## otherwise we set the verified time as 

	end


	def accept_as_verified?
		## will check the verified users, 
		## and if they satisfy the number condition
		## and role condition
		## then it works out
		## will run the verified_ids
		## throught the specified counts and roles
		## mentioned.
		## so let us have an array of roles in the organization.
		## And a user if applying to the organization
		## has to specify his or her role.
		## so now it is becoming more and more complicated.
		## so we have a partial saying -> if this document was to 
		## change, who will have to verify that change ?
		## suppose tomorrow you leave and there is only one pathologist.
		## then remove that member from the organization.
		## and it will work.
		## so now the organization has roles.
		## so we have to give the way for the organization to add the roles
		## then we have to give the way for the joiner to pick their role.
		## then add a versioned form, where they have to say that role -> count required for verification.

	end

	## for eg : 2 pathologists and 1 technician have to verify it.

end