## Embedded in Organization
## Embedded in Notification
require 'elasticsearch/persistence/model'
class Notification::Recipient

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::CallbacksConcern

	YES = 1
	NO = 0

	attribute :name, String, mapping: {type: 'keyword'}
	attribute :user_id, String, mapping: {type: 'keyword'}
	attribute :patient_id, String, mapping: {type: 'keyword'}
	attribute :phone_numbers, Array, mapping: {type: 'keyword'}
	attribute :email_ids, Array, mapping: {type: 'keyword'}
	
=begin
	before_validation do |document|
		document.patient_id = self.patient.id.to_s unless self.patient.blank?
		document.user_id = self.user.id.to_s unless self.user.blank?
	end
=end	
	validate :user_id_exists

	validate :patient_id_exists

	def user_id_exists
		unless self.user_id.blank?
			begin
				User.find(self.user_id)
			rescue
				self.errors.add(:user_id, "this user #{self.user_id} does not exist")
			end
		end
	end

	def patient_id_exists
		unless self.patient_id.blank?
			begin
				Patient.find(self.patient_id)
			rescue
				self.errors.add(:patient_id, "this patient #{self.patient_id} does not exist")
			end
		end
	end

	## this is read from the requisite arrays in the order itself.
	attr_accessor :resend
	attr_accessor :disabled
	attr_accessor :patient
	attr_accessor :user
	## once we add them, and we can set accessors
	## to these people
	## so it should auto add who all to this internally inside the order ?
	## that would be the best way to manage it.
	def self.permitted_params
		[
			:id,
			:name, 
			:patient_id,
			:user_id,
			{:phone_numbers => []},
			{:email_ids => []}
		]
	end

	def self.index_properties
		{
	    	name: {
	    		type: 'keyword',
	    		fields: {
		    			:raw => {
		    				:type => "text",
				      		:analyzer => "nGram_analyzer",
				      		:search_analyzer => "whitespace_analyzer"
		    			}
		    		}
	    	},
	    	user_id: {
	    		type: 'keyword'
	    	},
	    	phone_numbers: {
	    		type: 'keyword'
	    	},
	    	email_ids: {
	    		type: 'keyword'
	    	},
	    	patient_id: {
	    		type: 'keyword'
	    	}
	    }
	end

	def user_id_matches?(recipient)
		return false if (recipient.user_id.blank? || self.user_id.blank?)
		self.user_id == recipient.user_id
	end

	def phone_numbers_match?(recipient)
		return false if (self.phone_numbers.blank? || recipient.phone_numbers.blank?)
		!(self.phone_numbers & recipient.phone_numbers).blank?
	end

	def email_ids_match?(recipient)
		return false if (self.email_ids.blank? || recipient.email_ids.blank?)
		!(self.email_ids & recipient.email_ids).blank?
	end

	def patient_id_matches?(recipient)
		return false if (self.patient_id.blank? || recipient.patient_id.blank?)
		self.patient_id == recipient.patient_id
	end

	def matches?(recipient)
		[self.user_id_matches?(recipient),self.phone_numbers_match?(recipient),self.email_ids_match?(recipient),self.patient_id_matches?(recipient)].select{|c|
			!c.blank?
		}.size > 0	
	end

end