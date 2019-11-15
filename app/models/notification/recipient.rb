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

	attribute :user_id, String, mapping: {type: 'keyword'}
	attribute :patient_id, String, mapping: {type: 'keyword'}
	attribute :phone_numbers, Array, mapping: {type: 'keyword'}
	attribute :email_ids, Array, mapping: {type: 'keyword'}
	attribute :disable, Integer, mapping: {type: 'integer'}

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
			:disable,
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
	    	},
	    	disable: {
	    		type: 'integer'
	    	}
	    }
	end

	## first add all the relevant recipients.
	## the organization who created the order -> will include all the people registered in the organization variable called :default_recipients
	## the patient (if different)
	## and any additional recipients provided externally.
	## so these people will receive report notifications.
	## also there are -> 
	## so this is on the order
	## and in the organization -> we can add only users from that organization.
	## now how is the report sent ?
	## a link to the report is sent
	## and also to the android
	## what about notifications -> through status?
	## to whom should these be sent ?
	## like pre-test notifications -> and when should it be sent.
	## and to whom
	## so those go into status -> 
	## what about critical value notifications ?
	## so they are embedded in tags
	## and they will go to whom?
	## send to creator of order ?
	## all members of that organization ?
	## referring clinician?
	## either patient/creating_organization/reporting_organization/
	## so it can choose certain tag ids -> 
	## and in which organization ?
	## those people have to be notified.
	## in that organization.
	## plus lab created the order 
	## doctor's receptionist created the order
	## if the creating org is different from the reporting org
	## then 
	## it depends on the setting -> 
	## report will be sent to you be default
	## boy has left -> so on triggering that action
	## so build the recipients
	## you can add/remove
	## this action is done everytime on update/save
	## and inside tags we can have notifications
	## whether they should be sent to whom?
	## 	
	def user_id_matches?(recipient)
		self.user_id == recipient.user_id
	end

	def phone_numbers_match?(recipient)
		!(self.phone_numbers & recipient.phone_numbers).blank?
	end

	def email_ids_match?(recipient)
		!(self.email_ids & recipient.email_ids).blank?
	end

	def patient_id_matches?(recipient)
		self.patient_id == recipient.patient_id
	end

	def matches?(recipient)
		self.user_id_matches?(recipient) || self.phone_numbers_match?(recipient) || self.email_ids_match?(recipient) || self.patient_id_matches?(recipient)
	end

end