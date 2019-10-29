require 'elasticsearch/persistence/model'
class Patient

	include Elasticsearch::Persistence::Model
	include Concerns::MissingMethodConcern
	include Concerns::AllFieldsConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::NameIdConcern
	include Concerns::CallbacksConcern
	
	## so i can try to finish this today 
	## if all goes well.

	MALE = "Male"
	FEMALE = "Female"
	TRANSGENDER = "Transgender"
	SEX = ["Male","Female","Transgender","All"]
	YES = 1
	NO = 0

	index_name "pathofast-patients"	

	## does it have an array of history objects ?
	## each object can have any number of parameters ?
	## each type of history can be different ?
	## like on adding a particular report -> it will require certain histories to be taken
	## for eg : beta-hcg -> should i embed it in the report itself ?
	## instead of the patient ?
	## will be easier to embed.
	## don't touch the patient.
	## we will have to give that option everywhere else as well.
	## so in effect it can only create one user per mobile_number for one organization.
	## so we have some tags ?
	## that need to be filled ?
	## better to have a history object
	## these will be tags only.
	## like phase of menstrual cycle ->
	## and then we can define these inside ranges/reports.
	## you can edit/add these later
	## each history object is on the order or the patient ?
	## order -> 
	## so it will choose the required history tags. and add them to the order
	## so the order will embed many histories -> this will be done after adding the report.  
	## we can do name id concern.
	## if it does 
	## so the test will just have some tags -> these will be used to check for history questions.
	## so the history is an independent object ? or piggy back on tag with type ?
	## so the tag can have options
	## and we can refer to these tags in the reports -> create those histories
	## and use them in the ranges.
	## problem is that tag options can be ranges , like 
	## 10 - 20
	## 30 - 40
	## test can have required histories.
	before_save do |document|
		document.assign_id_from_name(nil)
	end

	def is_organization_representative_patient?
		self.organization_representative_patient == YES
	end

	## so we do a seperate id assignment for that.first
	def assign_id_from_name(organization_id)
		## here we have to bypass this.
		if self.is_organization_representative_patient?
			self.id = BSON::ObjectId.new.to_s
		else
			if ((self.id.blank?) && (!self.mobile_number.blank?))
				if !self.created_by_user.organization.is_a_patient?
					self.id = self.created_by_user.organization.id.to_s + "-" + self.mobile_number 
				else
					self.id = self.mobile_number
				end
			end
		end
	end

	###########################################################
	##
	##
	## OPTIONAL PARAMETERS.
	##
	##
	###########################################################
	attribute :email, String

	###########################################################
	##
	##
	##
	## REQUIRED PARAMETERS
	##
	##
	###########################################################
	attribute :first_name, String, mapping: {type: 'keyword', copy_to: 'search_all'}
	validates_presence_of :first_name

	attribute :last_name, String, mapping: {type: 'keyword', copy_to: 'search_all'}
	validates_presence_of :last_name

	attribute :mobile_number, String, mapping: {type: 'keyword', copy_to: 'search_all'}
	validates_presence_of :mobile_number

	attribute :date_of_birth, DateTime
	validates_presence_of :date_of_birth

	attribute :referring_doctor, String, mapping: {type: 'keyword'}

	attr_accessor :current_age_in_hours

	attribute :address, String
	validates_presence_of :address

	attribute :sex, String
	validates_presence_of :sex

	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s

	attribute :organization_representative_patient, Integer, mapping: {type: 'integer'}, default: NO

	settings index: { 
	    number_of_shards: 1, 
	    number_of_replicas: 0,
	    analysis: {
		      	filter: {
			      	nGram_filter:  {
		                type: "nGram",
		                min_gram: 2,
		                max_gram: 20,
		               	token_chars: [
		                   "letter",
		                   "digit",
		                   "punctuation",
		                   "symbol"
		                ]
			        }
		      	},
	            analyzer:  {
	                nGram_analyzer:  {
	                    type: "custom",
	                    tokenizer:  "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding",
	                        "nGram_filter"
	                    ]
	                },
	                whitespace_analyzer: {
	                    type: "custom",
	                    tokenizer: "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding"
	                    ]
	                }
	            }
	    	}
	  	} do

	    mapping do
	      
		    indexes :first_name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    },
	   	 	copy_to: "search_all"

		    indexes :last_name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    },
	   	 	copy_to: "search_all"

		end

	end

	## can be either on or off
	attribute :allergies, Integer, mapping: {type: 'keyword'}

	attribute :anticoagulants, Integer, mapping: {type: 'keyword'}

	attribute :diabetic, Integer, mapping: {type: 'keyword'}

	attribute :asthmatic, Integer, mapping: {type: 'keyword'}

	attribute :heart_problems, Integer, mapping: {type: 'keyword'}

	attribute :medications_list, Array, mapping: {type: 'keyword'}
	
	after_find do |document|
		unless document.date_of_birth.blank?
			document.current_age_in_hours = (Time.now - document.date_of_birth)/3600.0
		end
	end
	
	#############################################################
	##
	##
	## Override from alert concern
	##
	##
	#############################################################
	def set_alert
		begin
			associated_user = User.find(self.mobile_number)
			if associated_user.verified_user_ids.include? self.id.to_s
				self.alert = "The Patient has verified this entry"
			elsif associated_user.rejected_user_ids.include? self.id.to_s
					self.alert = "The Patient has has rejected this entry"
			else
				self.alert = "The Patient's verification of this entry is pending."
			end
		rescue
			self.alert = "A patient with this mobile number, does not currently exist. Please ask them to create an account." 
		end
	end

	#############################################################
	##
	##
	## UTILITY METHODS USED IN VIEWS.
	##
	##
	#########################################
	def full_name
		self.first_name + " " + self.last_name
	end

	def age
		return nil unless self.date_of_birth
		now = Time.now.utc.to_date
  		now.year - date_of_birth.year - ((now.month > date_of_birth.month || (now.month == date_of_birth.month && now.day >= date_of_birth.day)) ? 0 : 1)
	end

	def alert_information
		alert = ""
		alert += " allergic," if self.allergies == 1
		alert += " on blood thinners," if self.anticoagulants == 1
		alert += " a diabetic," if self.diabetic == 1
		alert += " an asthmatic," if self.asthmatic == 1
		alert += " has heart problems" if self.heart_problems == 1
		return alert if alert.blank?
		return "The patient" + alert
	end

	def meets_range_requirements?(range)
		 if range.sex == self.sex
		 	if ((range.min_age <= self.current_age_in_hours) && (range.max_age >= self.current_age_in_hours))
		 		return true
		 	end
		 end
		 return false
	end

	def self.permitted_params
		[:id , {:patient => [:first_name,:last_name,:date_of_birth, :sex, :email, :mobile_number, :address, :allergies, :anticoagulants, :diabetic, :asthmatic, :heart_problems, {:medications_list => []}, :referring_doctor, :organization_representative_patient]}]
	end

	## @return[Patient] : a dummy patient with the organization_representative_patient set as YES.
	## @called_from : Patient#find_or_create_organization_patient
	def self.create_representative_patient
		new(first_name: BSON::ObjectId.new.to_s, last_name: BSON::ObjectId.new.to_s, sex: MALE, mobile_number: rand.to_s[2..11], date_of_birth: Time.now, organization_representative_patient: YES, address: BSON::ObjectId.new.to_s)
	end

	## @param[String] organization_id : the id of the organization for which we are searching the representative patient.
	## @return[Patient] representative_patient: the representative patient of the this organization.
	## @called_from : Patient#find_or_create_organization_patient
	## @called_from : Organization#load_representative_patient
	def self.find_representative_patient(organization_id)
		representative_patient = nil
		search_request = Patient.search({
			query: {
				bool: {
					must: 
					[
						{
							term: {
									organization_representative_patient: YES
							}
						},
						{
							term: {
								owner_ids: organization_id
							}
						}
					]
				}
			}
		})
		search_request.response.hits.hits.each do |hit|
			representative_patient = Patient.new(hit._source)
			representative_patient.id = hit._id
		end
		representative_patient
	end

	## now make an order with the representative patient.
	## how does balance work.
	## as usual.
	## in the organization view.
	## i want to see that.

	## @param[String] organization_id
	## @param[String] user_id_who_created_organization
	## @called_from : Organization: after_save , which is in turn triggered from the base_controller_concern#create 
	## @return[Patient] : the dummy patient created to act on behalf of the organization
	## @working : will either find or create the representative patient of this organization.
	def self.find_or_create_organization_patient(organization_id,user)
		representative_patient = find_representative_patient(organization_id)
		
		if representative_patient.blank?
			## so this is the representative patient.
			representative_patient = create_representative_patient
			representative_patient.created_by_user = user
			representative_patient.created_by_user_id = user.id.to_s
			representative_patient.owner_ids << organization_id
			representative_patient.skip_owners_validations = true
			representative_patient.save
		end
		representative_patient
	end

	def has_history?
		false
	end

	alias name full_name




end