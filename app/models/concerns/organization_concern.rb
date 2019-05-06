module Concerns::OrganizationConcern
	## this is only meant to be used with user.
	## this is not meant to be used anywhere else.
	extend ActiveSupport::Concern

	included do 

		PATIENT = "patient"

	  	LAB = "lab"

	  	DOCTOR = "doctor"

	  	CORPORATE = "corporate"

	  	ROLES = [PATIENT,DOCTOR,LAB,CORPORATE]

		field :organization_id, type: String

		field :verified_as_belonging_to_organization, type: Boolean, :default => false

		field :role, type: String, :default => PATIENT

		field :employee_role_id, type: String

		## so this means if you add an organization id
		## it wants a role.
		## now do you go with modal or what ?
		## first of all in profiles_controller we need 
		## employee_role_id to be permitted.
		## go for modal on organization page.
		## load by ajax the options of that organization ?
		## or we can show that as a dropdown slideout.
		## both will go by ajax.
		## We already have loaded the roles.

		validates_presence_of :employee_role_id, :if => Proc.new{|c| !c.organization_id.blank?}

		attr_accessor :organization

		after_find do |document|
			document.get_organization_created_by_user
			document.get_organization_to_which_user_belongs
		end
	end

	###############################################
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

			end
		end
	end

	## an organization to which the user has applied.
	## not necessarily verified or rejected.
	## and not rejected ?
	## for what, let him see that as well.
	def get_organization_to_which_user_belongs
		if self.organization.blank?
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

	def is_an_organization_role?
      (is_a_lab? || is_a_doctor? || is_a_corporate?)
    end

    def is_a_patient?
       ((!self.role.blank?) && (self.role == self.class::PATIENT))
    end


    def is_a_lab?
      ((!self.role.blank?) && (self.role == self.class::LAB))
    end


    def is_a_doctor?
      ((!self.role.blank?) && (self.role == self.class::DOCTOR))
    end


    def is_a_corporate?
      ((!self.role.blank?) && (self.role == self.class::CORPORATE))
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

end