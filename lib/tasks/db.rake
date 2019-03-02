namespace :db do
  desc "Creates two dummy tests, one report containing those tests and one patient"
  task seed: :environment do
  	t = Test.new(name: "MCV", lis_code: "MCV", price: 100)
	t.save

	t2 = Test.new(name: "MCH", lis_code: "MCH", price: 100)
	t2.save

	report = Report.new(name: "Hemogram", test_ids: [t.id.to_s, t2.id.to_s])
	report.save

	patient = Patient.new(first_name: "Bhargav", last_name: "Raut")
	patient.save
  end

end
