require 'elasticsearch/persistence/model'
class Report

	include Elasticsearch::Persistence::Model

	attribute :test_ids, Array

	attribute :patient_id, String

	attribute :report_name, String

	## where are the packets assigned ?
	## here only the packet id should go
	## also individual tube ids.
	## we have to replace one tube with another.
	## so wherever that tube was there, it has to replace with another one.
	## we want to split tubes
	## we want stuff on the immunoassay to go to one tube
	## and stuff on the em to go to another tube.
	## the whole packet faield.
	## rst tube failed.
	## we will have to have some kind of bunching of the patient order.
	## order status -> collection done.
	## then it will assign the tubes.
	## please confirm
	## only then it will assign.
	## at that stage, not later.
	## this can have many tests in it.
	## like for hemogram, it has many tests in it.
	## so they should be seen together.
	## a package has many reports.
	## a report has many tests
	## reports can be chosen.
	## tests are basically copied over.
	## reports are just groups of tests and beyond that nothing.
	## so we make new reports
	## tests have no knowledge of reports
	## the test ids are stored in the report templates.
	## when a report is assigned to a patient,
	## it creates a new report.
	## and clones all the tests in that report template
	## patient id is added to both report and test.
	## patient name is also added.
	## packet id has to be loaded at the same time,
	## then tests are added directly to known tubes.
	## it makes a new session on that tube.
	## and only queries the latest session on the tube.
	## tubes have a time of addition
	## it will ask if the previous tests have been run or not.
	## and only add them.
end