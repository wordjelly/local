require 'elasticsearch/persistence/model'

class Organization
	
	include Elasticsearch::Persistence::Model
	
	index_name "pathofast-organizations"
	
	include Concerns::NameIdConcern
	include Concerns::AllFieldsConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	DEFAULT_LOGO_URL = "/assets/default_logo.svg"

	attribute :name, String, mapping: {type: 'keyword'}

	attribute :address, String, mapping: {type: 'keyword'}
	
	attribute :phone_number, String, mapping: {type: 'keyword'}

	attribute :description, String, mapping: {type: 'keyword'}

	attribute :user_ids, Array, mapping: {type: 'keyword'}, default: []

	LAB = "lab"

  	DOCTOR = "doctor"

  	CORPORATE = "corporate"

  	DISTRIBUTOR = "distributor"

  	SUPPLIER = "supplier"

  	ROLES = [DOCTOR,LAB,CORPORATE,DISTRIBUTOR,SUPPLIER]

	attribute :role, String, mapping: {type: 'keyword'}
	validates_presence_of :role

	## so these are actually the roles we specify on the employee.
	## but the employee is by default a patient.
	## if he chooses patient, it creates an organization whose role is a patient.
	## or on joining an organization.
	## can we have organization type?
	## employee cannot have.
	## so he has no default role.

	attribute :rejected_user_ids, Array, mapping: {type: 'keyword'}, default: []

	## how many users are necessary to verify any change in a document that
	## includes the versioned Concern.
	attribute :verifiers, Integer, mapping: {type: 'integer'}, default: 2

	## the different roles that can be there in this organizations.
	## basically searches the public tags or the tags of this organization
	attribute :role_ids, Array, mapping: {type: 'keyword'}

	## loaded from role_ids.
	## this is to define which employee roles are set on this
	## organization.
	## by default loaded from tags, all the tags whcih have tag_type 
	## as employee_role
	attr_accessor :employee_roles
	attr_accessor :role_name


	attr_accessor :users_pending_approval
	attr_accessor :verified_users
	attr_accessor :rejected_users


	validates_presence_of :address

	validates_presence_of :phone_number

	## so there have to be some roles.
	## let me make the ui to accept a role.
	## can i launch a modal ?
	## on show organization.
	## with a link with the role.
	## so user has to have something called an organization_role_id.
	## max types of employees in an organization can be 10.
	#validates_length_of :role_ids, :minimum => 1, :maximum => 10
	## so this means you have to make some roles while creating the organization.
	## so lets start with that
	## before that get tags working.

	
    mapping do
      
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"

	    indexes :address, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"

	    indexes :phone_number, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"

	end

	before_save do |document|
		document.public = Concerns::OwnersConcern::IS_PUBLIC
		document.assign_employee_roles
	end

	after_find do |document|
		document.load_users_pending_approval
		document.load_verified_users
		document.load_rejected_users
		document.load_employee_roles
	end

	## so these are the permitted params.
	def self.permitted_params
		puts "using permitted params -------------------"
		[:id,{:organization => [:role, :name, :description, :address,:phone_number, {:user_ids => []}, :role_name,  {:role_ids => []}, {:rejected_user_ids => []}] }]
	end

	############################################################
	##
	##
	## HELPER METHODS.
	##
	##
	############################################################
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

    def is_a_supplier?
      ((!self.role.blank?) && (self.role == self.class::SUPPLIER))
    end
    ## so now while making the organization this is complusory
    ## we put it in the form.
    ## and we 
	############################################################
	##
	##
	## CALLBACK METHODS.
	##
	##
	############################################################
	def load_users_pending_approval
		result = User.es.search({
			body: {
				query: {
					bool: {
						must: [
							{
								term: {
									organization_id: self.id.to_s
								}
							}
						],
						must_not: [
							{
								ids: {
									values: self.user_ids
								}
							}
						]
					}
				}
			}
		})

		#puts result.results.to_s

		#puts "came to after find to set the users pending approval."
		self.users_pending_approval ||= []
		result.results.each do |res|
			puts "the user pending approval is: #{res}"
			self.users_pending_approval << res
		end

	end

	def load_verified_users
		self.verified_users = []
		self.user_ids.each do |uid|
			self.verified_users << User.find(uid)
		end
	end

	def load_rejected_users
		self.rejected_users = []
		self.rejected_user_ids.each do |ruid|

			self.rejected_users << User.find(ruid)

		end
	end

	def load_employee_roles
		self.employee_roles ||= []
		self.role_ids.each do |rid|
			self.employee_roles << Tag.find(rid)
		end
	end	
	
	def assign_employee_roles
		## we can do this based on the role of the organization search for specific types of tags.
		## for now let this be.
		if self.role_ids.blank?
			self.role_ids = []
			request = Tag.search({
				size: 10,
				query: {
					bool: {
						must: [
							{
								term: {
									tag_type: Tag::EMPLOYEE_TAG
								}
							}
						]
					}
				}
			})	
			request.response.hits.hits.each do |hit|
				self.role_ids << hit["_id"]
			end	
		end
	end
	############################################################
	##
	##
	## OVERRIDDEN from ALERT_CONCERN
	##
	##
	############################################################
	def set_alert
		## how do we delete it.
		self.alert = ""
		if self.images.blank?
			self.alert += "1.You are using the default logo, please upload an image of your own logo"
		end
		if self.role_ids.blank?
			self.alert += "2. Please add some employee roles by visiting TAGS, these will be added to your organization."
		end
	end

	## dob is not working in profiles page
	## 

end