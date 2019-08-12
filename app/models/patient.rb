require 'elasticsearch/persistence/model'
class Patient

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::NameIdConcern
	include Concerns::MissingMethodConcern

	SEX = ["Male","Female","Transgender","All"]

	index_name "pathofast-patients"	

	## we will have to give that option everywhere else as well.
	## so in effect it can only create one user per mobile_number for one organization.
	## we can do name id concern.
	## if it does 
	before_save do |document|
		document.assign_id_from_name(nil)
	end

	def assign_id_from_name(organization_id)
		if ((self.id.blank?) && (!self.mobile_number.blank?))
			if !self.created_by_user.organization.is_a_patient?
				self.id = self.created_by_user.organization.id.to_s + "-" + self.mobile_number 
			else
				self.id = self.mobile_number
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

	attr_accessor :current_age_in_hours

	attribute :address, String
	validates_presence_of :address

	attribute :sex, String
	validates_presence_of :sex

	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s

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
		    }

		    indexes :last_name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

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
		puts "doing after find for PATIENT ==============="
		unless document.date_of_birth.blank?
			puts "date of birth is not blank."
			document.current_age_in_hours = (Time.now - document.date_of_birth)/3600.0
			puts "current age in hours is:"
			puts document.current_age_in_hours
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
		 puts "came to check meets range requiremetns."
		 puts "range sex is: #{range.sex}"
		 puts "self sex si: #{self.sex}"
		 puts "range min age is: #{range.min_age}"
		 puts "range max age is: #{range.max_age}"
		 puts "current age in hours: #{self.current_age_in_hours}"
		 if range.sex == self.sex
		 	if ((range.min_age <= self.current_age_in_hours) && (range.max_age >= self.current_age_in_hours))
		 		puts "will return TRUE."
		 		return true
		 	end
		 end
		 puts "will return FAlSE"
		 return false
	end

	def self.permitted_params
		[:id , {:patient => [:first_name,:last_name,:date_of_birth, :sex, :email, :mobile_number, :address, :allergies, :anticoagulants, :diabetic, :asthmatic, :heart_problems, {:medications_list => []}]}]
	end

end