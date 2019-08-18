require 'elasticsearch/persistence/model'

class Organization
	
	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::EsBulkIndexConcern
	## ORDER OF LOCATION CONCERN AFTER THE MISSING METHOD CONCERN
	## AND ALSO THE CASCADE CALLBACK IS IMPORTANT
	## IS IMPORTANT. THE BEFORE_SAVE CALLBACK IN THE LOCATION CONCERN
	## NEEDS THE ORGANIZATIONS ID.
	include Concerns::MissingMethodConcern
	
	before_save do |document|
		cascade_id_generation(nil)
	end
	
	include Concerns::LocationConcern
	
		
	index_name "pathofast-organizations"
	document_type "organization"
		

	DEFAULT_LOGO_URL = "/assets/default_logo.svg"

	USER_VERIFIED = "Verified"
	USER_PENDING_VERIFICATION = "Pending Verification"
	USER_REJECTED = "Rejected"
	OWNER_EMPLOYEE_ROLE_ID = "Owner"
	YES = 1
	NO = 0

	## 1 centimeter is 37.7952755906
	CM_TO_PIXEL = 37.7952755906

	

	attribute :name, String, mapping: {type: 'keyword'}

	#attribute :address, String, mapping: {type: 'keyword'}
	# lis security key is generated be default, and displayed
	## it is never accepted as an external parameter.	
	attribute :lis_security_key, String, mapping: {type: 'keyword'}, default: Devise.friendly_token.first(25)

	## the primary phone number.
	attribute :phone_number, String, mapping: {type: 'keyword'}

	## the fax number
	attribute :fax_number, String, mapping: {type: 'keyword'}

	## the website
	attribute :website, String, mapping: {type: 'keyword'}

	## what facilities you have.
	attribute :facilities, Array, mapping: {type: 'keyword'}

	## What accredditation you have.
	attribute :accreditations, Array, mapping: {type: 'keyword'}

	## your timings -> mon-sun : 8 am to 8 pm, sun closed
	attribute :timings, Array, mapping: {type: 'keyword'}

	## alternative phone numbers
	attribute :alternative_phone_numbers, Array, mapping: {type: 'keyword'}

	## locations of different centers.
	attribute :centers, Array, mapping: {type: 'keyword'}

	## what is the slogan of the organization.
	attribute :slogan, String, mapping: {type: 'keyword'}

	attribute :description, String, mapping: {type: 'keyword'}

	attribute :user_ids, Array, mapping: {type: 'keyword'}, default: []

	LAB = "lab"

  	DOCTOR = "doctor"

  	CORPORATE = "corporate"

  	DISTRIBUTOR = "distributor"

  	SUPPLIER = "supplier"

  	ROLES = [DOCTOR,LAB,CORPORATE,DISTRIBUTOR,SUPPLIER]

  	PATIENT = "patient"

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

	## i can have a before_merge hook.
	## it can check which params have changed.
	## if the new attributes are 

	attribute :parent_id, String, mapping: {type: 'keyword'}

	attribute :children, Array, mapping: {type: 'keyword'}
	## loaded from role_ids.
	## this is to define which employee roles are set on this
	## organization.
	## by default loaded from tags, all the tags whcih have tag_type 
	## as employee_role
	attr_accessor :employee_roles
	attr_accessor :role_name

	## these are loaded via elasticsearch.
	## and i think its not calling after_find callback.
	attr_accessor :users_pending_approval
	
	## both these are set when the organization is set
	## after_find in organization_concern, triggers
	## set_organization -> which by default sets to the
	## first organization in the users organization members
	## when the organization is set, (on the user) if the user owns the organization, then this accessor is set to "yes"
	## then the second step is the base_controller_concern before_action
	## which sets by using the header
	## in that case also when the organization is set, there too this accessor is set.
	attr_accessor :owned_by_current_user
	attr_accessor :current_user_role_id

	OWNED_BY_CURRENT_USER = YES

	attr_accessor :locations

	validates_presence_of :phone_number

	#########################################################
	##	##
	## REPORT OPTIONS
	## FOR YOUR OWN ORGANIZATION
	##
	#########################################################
	
	# each report in the pdf should be on a new page
	attribute :each_report_on_new_page, Integer, mapping: {type: 'integer'}, default: YES

	# generates pdf's of orders, where all reports are not yet verified
	attribute :generate_partial_order_reports, Integer, mapping: {type: 'integer'}, default: YES
	
	# signatures 
	# eg : lab owner, some technician etc.
	# these signatures will be added in addition to the doctor who has signed the report
	attribute :additional_employee_signatures, Array, mapping: {type: 'keyword'}
		
	# user ids of doctors/employees who can verify the reports.
	attribute :who_can_verify_reports, Array, mapping: {type: 'keyword'}

	# whether letter head should be printed or not?
	attribute :we_have_pre_printed_letter_heads, Integer, mapping: {type: 'integer'}, default: NO

	DEFAULT_HEADER_SPACE_TO_LEAVE = 5.0

	attribute :space_to_leave_for_pre_printed_letter_head_in_cm, Float, mapping: {type: 'float'}, default: DEFAULT_HEADER_SPACE_TO_LEAVE

	
	# whether you have pre printed footers
	attribute :we_have_pre_printed_footers, Integer, mapping: {type: 'integer'}, default: NO


	DEFAULT_FOOTER_SPACE_TO_LEAVE = 5.0

	attribute :space_to_leave_for_pre_printed_footer_in_cm, Float, mapping: {type: 'float'}, default: DEFAULT_FOOTER_SPACE_TO_LEAVE


	attribute :generate_header, Integer, mapping: {type: 'integer'}, default: YES

	
	DEFAULT_PARAMETERS_TO_INCLUDE_IN_HEADER = ["phone_number","address","name","timings"]

	attribute :parameters_to_include_in_header, Array, mapping: {type: 'keyword'}, default: DEFAULT_PARAMETERS_TO_INCLUDE_IN_HEADER	

	attribute :show_patient_details_on_each_page, Integer, mapping: {type: 'integer'}, default: YES

	#########################################################
	##
	##
	## REPORT OPTIONS
	## FOR OUTSOURCED REPORTS
	##
	#########################################################

	## if you want it on the outsourced organization letter head, then it will have to be generated on a seperate page
	## and it will be signed by their doctors.
	## in this case, do these in the end.
	## still group by signing authority.
	## if they are being generated on your letter head.
	## then -> 
	attribute :outsourced_reports_have_original_format, Integer, mapping: {type: 'integer'}, default: NO

	## if you want it directly on your letter head, then do you want a sign on it or not.
	## if yes, then it will be signed.
	## apply our letter head settings (could be blank, then it will have the sign of those who sign your outsourced reports.)
	## if this is yes -> then it will also have to be provided something for which of our employees will sign outsourced reports.
	attribute :use_our_letter_head_settings_for_outsourced_reports, Integer, mapping: {type: 'keyword'}, default: 1

	attribute :which_of_our_employees_will_resign_outsourced_reports,Array, mapping: {type: 'keyword'}, default: [] 

	## so that's it, for the options 
	## now just determine whose report it is and render.
	attribute :add_processed_at_footnote_if_using_our_letter_head, Integer, mapping: {type: 'integer'}, default: YES

	#########################################################
	##
	##
	## 
	##
	##
	#########################################################

    mapping do
      
	    indexes :name, type: 'keyword', fields: {
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

	## we add the parent child thing as a validation
	## so that if it fails this does not succeed.
	before_save do |document|
		document.public = Concerns::OwnersConcern::IS_PUBLIC
		document.assign_employee_roles
	end

	after_save do |document|
		document.update_creating_user_organization_members
		document.update_parent_chain
	end

	after_find do |document|
		document.load_users_pending_approval
		document.load_employee_roles
		document.load_locations
	end

	## so these are the permitted params.
	def self.permitted_params

		base = 
		[
			:id,
			{:organization => 
				[
				 :parent_id,
				 :role,
				 :name,
				 :description,
				 :phone_number, 
				 {:user_ids => []},
				 :role_name,  
				 {:role_ids => []}, 
				 {:rejected_user_ids => []}, 
				 :each_report_on_new_page,
				 :generate_partial_order_reports, 
				 {:additional_employee_signatures => []},
				 {:who_can_verify_reports => []},
				 :we_have_pre_printed_letter_heads,
				 :space_to_leave_for_pre_printed_letter_head_in_cm, 
				 :we_have_pre_printed_footers, 
				 :space_to_leave_for_pre_printed_letter_head_in_cm, 
				 :generate_header,
				 {:parameters_to_include_in_header => []}, 
				 :show_patient_details_on_each_page, 
				 :outsourced_reports_have_original_format, 
				 :use_our_letter_head_settings_for_outsourced_reports,
				 {:which_of_our_employees_will_resign_outsourced_reports => []},
				 :add_processed_at_footnote_if_using_our_letter_head
				] 
			}
		]

		if defined? @permitted_params
			base[1][:organization] << @permitted_params
			base[1][:organization].flatten!
		end
		base
	end

	## so we will need a class variable for this.
	## for using this @permitted_params.
	## or we can override as json
	## and use that.
	## we need a class level method for this.
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
		## okay so here we have to do the nested search.
		#puts "CAME TO LOAD USERS PENDING APPROVAL"
		#puts "self id is:"
		#puts self.id.to_s

		query = {
			body: {
				query: {
					bool: {
						must: [
							{
								nested: {
									path: "organization_members",
									query: {
										bool: {
											must: [
												{
													term: {
														"organization_members.organization_id".to_sym => self.id.to_s
													}
												}
											],
											must_not: [
												{
													term: {
														"organization_members.created_by_this_user".to_sym => OrganizationMember::CREATED_BY_THIS_USER
													}
												}
											]
										}
									}
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
		}

		#puts "pending user query is ------------------------------------>"
		#puts JSON.pretty_generate(query)

		result = User.es.search(query)

		#puts result.to_s
		#puts result.methods.to_s

		self.users_pending_approval ||= []
		result.results.each do |res|
			#puts "the user pending approval is: #{res}"
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

	## i will finish locations.

	def load_locations
	 	
	 	self.locations = []

	 	search_request = Geo::Location.search({
	 		query: {
	 			term: {
	 				model_id: self.id.to_s
	 			}
	 		}
	 	})

	 	search_request.response.hits.hits.each do |hit|
	 		location = Geo::Location.new(hit["_source"])
	 		location.id = hit["_id"]
	 		location.run_callbacks(:find)
	 		self.locations << location
	 	end

	 	## so this is the organization's location
	 	## this is used in location concern.
	 	## we can use that in the organization also.
	 	
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

	def has_verified_user?(user_id)
		self.user_ids.include? user_id
	end

	## membership status.
	## boring shit.

	def has_rejected_user?(user_id)
		self.rejected_user_ids.include? user_id
	end

	def has_user_pending_verification?(user_id)
		self.users_pending_approval.map{|c| c = c.id.to_s}.include? user_id
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

	## @return[Array] organizations: the current organization id and the ids of all the child organizations
	def all_organizations
		([self.id.to_s] + self.children).flatten
	end
	####################################################
	##
	##
	## after_save callbacks.
	##
	##
	####################################################
	def update_creating_user_organization_members
		

		u = User.find(self.created_by_user_id)
		
		existing_organization = u.organization_members.select{|c|
			c.organization_id == self.id.to_s
		}

		if existing_organization.blank?
			u.organization_members.push(OrganizationMember.new(:organization_id => self.id.to_s, :employee_role_id => Organization::OWNER_EMPLOYEE_ROLE_ID, :created_by_this_user => "yes"))
			u.skip_authentication_token_regeneration = true
			u.save
		end

	end	

	## if the parent is removed, then how does it work.
	## this will add it.
	## what about removing ?
	## 
	def update_parent_chain
		## okay so there is some deprecation 
		## here on the newer elasticsearch version.
		current_org = self
		
		search_request = Organization.search({
			query: {
				term: {
					children: self.id.to_s
				}
			},
			aggregations: {
				parent_organizations: {
					terms: {
						field: "_id"
					}
				}
			}
		})
		
		## so the id can be a base64 slug.
		## that is created from that ?
		## we can do something like that. 

		#puts "=-&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&== updating parent chain"


		search_request.response.aggregations.parent_organizations.buckets.each do |porg_bucket|

			organization_id = porg_bucket["key"]

			source = '''
				for(orphan in params.orphans){
					ctx._source.children.removeIf(item -> item == orphan);
				}
			'''
			params = {
				orphans: ([self.id.to_s] + (self.children || [])).flatten
			}
			update_hash = {
				update: {
					_index: self.class.index_name,
					_type: self.class.document_type,
					_id: organization_id,
					data: { 
						script: 
						{
							source: source,
							lang: 'painless', 
							params: params
						}
					}
				}
			}

			puts "the delete update hash is :"
			puts update_hash.to_s
			puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

			Organization.add_bulk_item(update_hash)
			Organization.flush_bulk
		end

		while true
			puts "the current org parent id is:"
			puts current_org.parent_id.to_s
			break unless current_org.parent_id
			parent = Organization.find(current_org.parent_id)
			source = '''
				if(!ctx._source.children.contains(params.child_organization_id)){

					ctx._source.children.add(params.child_organization_id);
				}
			'''
			params = {
				child_organization_id: self.id.to_s
			}
			update_hash = {
				update: {
					_index: self.class.index_name,
					_type: self.class.document_type,
					_id: parent.id.to_s,
					data: { 
						script: 
						{
							source: source,
							lang: 'painless', 
							params: params
						}
					}
				}
			}
			Organization.add_bulk_item(update_hash)
			## now add the bulk request.
			current_org = parent
		end
		Organization.flush_bulk
	end

	
end