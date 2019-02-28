require 'elasticsearch/persistence/model'
class Report

	include Elasticsearch::Persistence::Model

	index_name "pathofast-reports"

	attribute :template_report_id, String

	attribute :test_ids, Array

	attr_accessor :test_name
	attr_accessor :test_id_action
	attr_accessor :test_id
	attribute :tests, Array

	attribute :patient_id, String

	attribute :name, String

	attribute :price, Float

	attribute :item_requirement_ids, Array

	attr_accessor :item_requirement_name
	attr_accessor :item_requirement_id_action
	attr_accessor :item_requirement_id
	attribute :item_requirements, Array

	## what kind of images are needed
	## references
	## signatures
	## alert criteria.
	## pdf generation of the report
	## verification.
	## direct verification, or individual test verification.
	## on verification sending emails/sms.
	## total -> pdf.
	## report -> pdf (emailing and smsing)
	## adding tests
	## removing tests
	## splitting tests
	## summary of abnormal values.
	## updating item statuses.(image, location, status, so we can keep a status_update object and work with that)


	before_save do |document|
		if document.test_id_action
			if document.test_id_action == "add"
				document.test_ids << document.test_id
			elsif document.test_id_action == "remove"
				document.test_ids.delete(document.test_id)
			end
		elsif document.item_requirment_id_action
			if document.item_requirement_id_action == "add"
				document.item_requirement_ids << document.item_requirement_id
			elsif document.item_requirement_id_action == "remove"
				document.item_requirement_ids.delete(document.item_requirement_id)
			end
		end
	end

	#attribute :required_image_ids, Array
	## what kind of pictures are necessary
	## before releasing this report ?
	## rapid kit image
	## blood grouping card image
	## optional images of test_tubes
	## graph image for hba1c

	## what type of items does it need?
	## for eg : item type (red top tube/ orange top/ golden top, uses 5%, min amount, and max amount.)
	## this will be called a report_item_requirement.
	## will be an item type, a amount, optional
	## priority.
	

	def clone(patient_id)
		
		patient_report = Report.new(self.attributes.merge({patient_id: patient_id, template_report_id: self.id.to_s}))
		
		patient_report.test_ids = []
		
		self.test_ids.each do |test_id|
			t = Test.find(test_id)
			patient_test = t.clone(patient_id)
			patient_report.test_ids << patient_test.id.to_s
		end

		patient_report

	end

	def load_tests
		self.tests ||= []
		self.test_ids.each do |tid|
			self.tests << Test.find(tid)
		end
	end

	def load_item_requirements
		self.item_requirements ||= []
		self.item_requirement_ids.each do |iid|
			self.item_requirements << ItemRequirement.find(iid)
		end
	end

end