module Concerns::OrganizationConcern
	## this is only meant to be used with user.
	## this is not meant to be used anywhere else.
	extend ActiveSupport::Concern

	included do 

		ORGANIZATION_ID_HEADER = "X-User-Organization-Id"
		#this happens after finding the user
		#in token concern, or wherever.
		#i'll have to override that, to preset the organization, based on whatever is chosen, if it is found to be belonging to that one.
		#and user will have an array of organization ids.
		#

		#PATIENT = "patient"

	  	#LAB = "lab"

	  	#DOCTOR = "doctor"

	  	#CORPORATE = "corporate"

	  	#ROLES = [PATIENT,DOCTOR,LAB,CORPORATE]

		field :organization_id, type: String

		## this is a part of the newer api.
		## get this into the index.
		## let me finish this first, and add it to the form.
		## and then move forwards.
		## after this will be the organization subjugation
		## and the location updates.
		## when he has chosen the organization id, it 
		## can derive those things.
		embeds_many :organization_members, class_name:"OrganizationMember"

		## these are permitted, as being easy to add to the form.
		## so what hapepns with this exactly ?
		## before save we can add if it doesn't exist.
		## that we can do.
		## or add it to the array.
		## if it doesn't exist.
		field :organization_member_organization_id, type: String
		field :organization_member_employee_role_id, type: String

		#now let me add that to the form.
		#first, then the permitted params on profile.
		#field :member_of_organizations, type: Array
		## i think it is embeds_many.
		## but i don't really remember.
		## exactly.
		## embed many organizations.
		## before save it will add this, if it does not exist ?
		## or what will it do?
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
		attr_accessor :organizations


		## basically organizations become nested
		## each has an id, and a role id that you signed up as.
		## and then we search inside that.
		## the rest doesn't have to change much here.
		## but this will change.
		## and how the organization loads these users
		## will also change.
		## total complexity will get added of one day.
		## even if you create an organization.
		## so i created an organization
		## should get added to the same nested array.
		## after create
		## don't complicate all this so much.
		## all this is background.
		## he doesn't need to know it.

		attr_accessor :employee_role

		after_find do |document|
			document.set_membership_statuses_for_organization_members
			document.set_organization
		end



		before_save do |document|
			if document.organization_members.blank?
				document.organization_members = []
			end
		end
	end

	###############################################
	##
	##
	## update the created by user with the organization
	## i can override create in organization concern.
	## it can save the user after saving the organization
	## 
	##
	##
	###############################################
	## so let me rework all this.
	## still gotta do cascade and locations finalization
	###############################################
	##
	##
	##
	## GETTING THE USER'S ORGANIZATION, OR THE ORGANIZATION THAT HE HAS CREATED
	## THESE TWO ARE FIRED AFTER_FIND
	##
	##
	###############################################
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
    	return false unless has_organization?
    	return false if self.organization.owned_by_current_user.blank?
    	return self.organization.owned_by_current_user == Organization::OWNED_BY_CURRENT_USER
    end

    ## returns true if there is an organization id, and it has been verified
    ## otherwise no.
    def belongs_to_organization?
    	has_organization? && !is_organization_owner?
    end

    def owns_or_belongs_to_organization?
   		has_organization?
    end

    ## so this is the employee role.
    def load_employee_role
    	self.employee_role_id = Tag.find(self.organization.current_user_role_id)
    end

    def set_membership_statuses_for_organization_members
    	self.organization_members.each do |om|
    		om.set_membership_status(self.id.to_s)
    	end
    end

    def set_organization
    	#puts " ----------- !!!!!!!!!!!!!! ------------ "
    	#puts "Came to set organization"
    	#puts "the organization members are:"
    	#puts self.organization_members.to_s

    	if self.organization.blank?
    		k = self.organization_members.select{|c|
    			c.membership_status == Organization::USER_VERIFIED
    		}
    		#puts "organizations that were verified for this user are:"
    		#puts k.to_s
    		unless k.blank?
    			if self.organization = Organization.find(k[0].organization_id)
    				self.organization.current_user_role_id = k[0].employee_role_id
    				if k[0].created_by_this_user == OrganizationMember::CREATED_BY_THIS_USER
    					self.organization.owned_by_current_user = Organization::OWNED_BY_CURRENT_USER
    				end
    			end
    		end
    		#puts "the organization that was set for this user is $$$$$$$$$$$$$$$$$$$$$$$$$$$"
    		#puts self.organization.to_s
    	end
    end

    ## @param[Hash] headers : the hash of headers
    ## get on with it.
    def set_organization_from_header(headers)
    	puts "-----------------------------the headers coming in to the organization concern def are:----------------------"
    	puts headers.to_s
    	if headers[Concerns::OrganizationConcern::ORGANIZATION_ID_HEADER]
    		applicable_organizations = self.organization_members.select{|c|
    			((c.organization_id == headers[Concerns::OrganizationConcern::ORGANIZATION_ID_HEADER]) && (c.membership_status == Organization::USER_VERIFIED))
    		}
    		if applicable_organizations.size == 1
    			self.organization = Organization.find(applicable_organizations[0].organization_id)
    			self.organization.current_user_role_id = applicable_organizations[0].employee_role_id
    			self.organization.owned_by_current_user = Organization::OWNED_BY_CURRENT_USER if applicable_organizations[0].created_by_this_user == OrganizationMember::CREATED_BY_THIS_USER
    		end
    	end
    end

    ## the two fields  :organization_member_organization_id
    ## :organization_member_employee_role_id
    ## are populated when a user clicks join on the organiztion page
    ## they are sent to the edit page
    ## the form bit to add this latest organization
    ## to the organization members is rendered only 
    ## if this organization id is not already present
    ## in the users organization members
    ## this will not happen if the user has already added these, in a previous edit action
    ## since these two are fields, they are saved, so 
    ## this needs to be checked before rendering edit.
    def show_join_organization_form?
    	existing_member = self.organization_members.select{|c|
    		c.organization_id == self.organization_member_organization_id
    	}
    	existing_member.size == 0
    end

end