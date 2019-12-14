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
	include Concerns::FormConcern
	include Concerns::CallbacksConcern

	YES = 1
	NO = 0

	## ----------------------------------------------
	## THESE THREE THINGS ARE FINISHABLE TODAY.
	## solve the hba1c problem(don't know what is happening here, but if solved its the end of the show for us) - try to solve this now.
	## see if you can change the name for ACR -> for this we write a custom hl7 hack
	## just check if you are getting the name of the machine and port it out.
	## ---------------------------------------------
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

	def patient_id=(patient_id)
		begin
			p = Patient.find(patient_id)
			self.email_ids = [p.email] unless p.email.blank?
			self.phone_numbers = [p.mobile_number] unless p.mobile_number.blank?
		rescue
		end
		@patient_id = patient_id
	end

	def user_id=(user_id)
		begin
			u = User.find(user_id)
			self.email_ids = [u.email] unless u.email.blank?
			self.phone_numbers = [u.additional_login_param] unless u.additional_login_param.blank?
		rescue
		end
		@user_id = user_id
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

	## summary table headers
	#############################################################3
	##
	##
	## OVERRIDDEN FROM NESTED FORM.
	##
	##
	#############################################################
	## this gets overriden in the different things.
	def summary_row(args={})
		'
			<tr>
				<td>' + self.name + '</td>
				<td>' + (self.user_id || '') + '</td>
				<td>' + (self.patient_id  || '') + '</td>
				<td>' + self.phone_numbers.to_s + '</td>
				<td>' + self.email_ids.to_s + '</td
				<td><div class="edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		'''
			<thead>
	          	<tr>
	              	<th>Name</th>
			        <th>User Id</th>
			        <th>Patient Id</th>
			        <th>Phone Numbers</th>
			        <th>Email Ids</th>
			        <th>Options</th>
	          	</tr>
	        </thead>
		'''
	end

end