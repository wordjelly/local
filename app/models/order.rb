require 'elasticsearch/persistence/model'
class Order

	include Elasticsearch::Persistence::Model
	
	index_name "pathofast-orders"

	attribute :template_report_ids, Array


	attribute :patient_report_ids, Array


	attribute :patient_test_ids, Array


	attribute :items, Array[Hash]


	attribute :stage, String


	## takes the template report ids, and creates reports from that, as well as cloning all tests associated with those reports.
	def create_patient_reports
		self.template_report_ids.each do |report_id|
			report = Report.find(report_id)
			self.patient_report_ids << report.clone.id.to_s
			self.patient_test_ids << report.test_ids.map{|t| t.id.to_s}
			update_item_requirements
			update_pending_balance
		end
	end

	def update_item_requirements
		## what would the item look like ?
		## so the report will store how much serum is required.
		## 
		## item_type
		## item_id
		## item_group_id
		## registered_test_ids
		## registered_report_ids
		## I can call it a consumable,
		## not mapped to es.
		## just virtus.
		## imagine a tube coming from outside.
		## i would add a nested tube object
		## with the requirement if none exists.
		## if one exists(has id.), i would look it up and see if it can accomodate this test.
		## then i would add these parameters to the tests that have not yet got a value for that tube.
		## otherwise would create a new requirement.
		## 
		## array of hashes.
		## now suppose i want to search for a tube on autocomplete ?
		## goes through the tubes ?
		## of that type
		## sees if there is -> enough serum
		## still available at this time.
		## sees how 
		## serum_tube => 
	end

end