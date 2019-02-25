require 'elasticsearch/persistence/model'
class Patient

	include Elasticsearch::Persistence::Model

	index_name "pathofast-patients"

	attribute :first_name, String

	attribute :last_name, String

	attribute :email, String

	attribute :mobile_number, String

	attribute :date_of_birth, DateTime

	attribute :area, String

	attribute :allergies, Integer

	attribute :anticoagulants, Integer

	attribute :diabetic, Integer

	attribute :asthmatic, Integer

	attribute :heart_problems, Integer

	attribute :sex, String
	##########################################
	##
	##
	## UTILITY METHODS USED IN VIEWS.
	##
	##
	##########################################

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

end