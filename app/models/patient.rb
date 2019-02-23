require 'elasticsearch/persistence/model'
class Patient

	include Elasticsearch::Persistence::Model

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
		(Time.now - self.date_of_birth).years.to_s
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