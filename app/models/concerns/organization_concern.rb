module Concerns::OrganizationConcern
	## this is only meant to be used with user.
	## this is not meant to be used anywhere else.
	extend ActiveSupport::Concern

	included do 

		#PATIENT = "patient"

	  	#LAB = "lab"

	  	#DOCTOR = "doctor"

	  	#CORPORATE = "corporate"

	  	#ROLES = [PATIENT,DOCTOR,LAB,CORPORATE]

		field :organization_id, type: String

		## this is set after find, from the loaded organization.
		attr_accessor :verified_as_belonging_to_organization	

		## this is getting set on the user
		## that doesn't make any sense
		## it should be a part of the organization
		## and the employee role should be seperate.
		#field :role, type: String, :default => PATIENT

		field :employee_role_id, type: String

		## so that verified is never going to be true.
		## we are updating that on the organization side.
		## verified has to be set after find.
		## 

		validates_presence_of :employee_role_id, :if => Proc.new{|c| !c.organization_id.blank?}

		attr_accessor :organization
		attr_accessor :employee_role

		after_find do |document|
			document.get_organization_created_by_user
			document.get_organization_to_which_user_belongs
			document.set_verified_as_belonging_to_organization
			document.load_employee_role
		end
	end

	###############################################
	##
	##
	##
	## GETTING THE USER'S ORGANIZATION, OR THE ORGANIZATION THAT HE HAS CREATED
	## THESE TWO ARE FIRED AFTER_FIND
	##
	##
	###############################################

	def get_organization_created_by_user
		if self.organization_id.blank?
			search_results = Organization.search({
				query: {
					term: {
						owner_ids: self.id.to_s
					}
				}
			})
			unless search_results.response.hits.hits.blank?

				self.organization = Organization.find(search_results.response.hits.hits.first["_id"])

				self.verified_as_belonging_to_organization = true

			end
		end
	end

	## an organization to which the user has applied.
	## not necessarily verified or rejected.
	## and not rejected ?
	## for what, let him see that as well.
	def get_organization_to_which_user_belongs
		puts "trying to get the organization to which the user belongs"
		if self.organization.blank?
			puts "its organization is blank."
			puts "its organization id is: #{self.organization_id}"
			unless self.organization_id.blank?
				search_results = Organization.search({
					query: {
						bool: {
							must: [
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
					
					self.organization = Organization.find(search_results.response.hits.hits.first["_id"])
				end

			end
		end
	end

	## sets the value of the attr_accessor :verifed_as_belonging_to_organization
	## returns false unless there is an organization.
	## then checks if the user is there in the user_ids, of the organization, and returns the result of the checking that.
	def set_verified_as_belonging_to_organization
		if self.verified_as_belonging_to_organization.blank?
			if self.organization
				self.verified_as_belonging_to_organization = (self.organization.user_ids.include? self.id.to_s)
			else
				self.verified_as_belonging_to_organization = false 
			end
		end
	end


	def get_organization_name
		return ENV["LIS_NAME"] if self.organization.blank?
		return self.organization.name
	end

	def get_organization_phone_number
		return ENV["LIS_PHONE"] if self.organization.blank?
		return self.organization.phone_number
	end

	def get_organization_address
		return ENV["LIS_ADDRESS"] if self.organization.blank?
		return self.organization.address
	end

	def get_organization_logo_url
		return Organization::DEFAULT_LOGO_URL if self.organization.blank?
		return self.organization.logo_url
	end

    ## if an organization attribute was found for it.
    def has_organization?
      !self.organization.blank?
    end

    ## an organization was found for it, but 
    ## he does not have an organization id, so 
    ## he has to be the owner.
    def is_organization_owner?
    	has_organization? && self.organization_id.blank?
    end

    ## returns true if there is an organization id, and it has been verified
    ## otherwise no.
    def belongs_to_organization?
    	has_organization? && !self.organization_id.blank? && !self.verified_as_belonging_to_organization.blank?
    end

    

    def owns_or_belongs_to_organization?
   		is_organization_owner? || belongs_to_organization? 	
    end


    ## so this is the employee role.
    def load_employee_role
    	unless self.employee_role_id.blank?
    		self.employee_role = Tag.find(self.employee_role_id)
    	end
    end

    ## a user can transfer an object, if its organization owns
    ## that item, or it is the creator of that object.
    def can_transfer?(obj)
    	if obj.owner_ids.include? self.organization.id.to_s
    		return true
    	elsif obj.owner_ids.include? self.id.to_s
    		return true
    	end
    end

end