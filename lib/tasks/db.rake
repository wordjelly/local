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

	item_type_one = ItemType.new(name: "Lavender Tube")
	item_type_one.save

	item_type_two = ItemType.new(name: "Urine Tube")
	item_type_two.save

	item_requirement = ItemRequirement.new(name: "Hemogram Tube", item_type: item_type_one.name, optional: "no", priority: 1, amount: 50)
	item_requirement.save

	item_requirement_two = ItemRequirement.new(name: "Urine Tube", item_type: item_type_two.name, optional: "no", priority: 1, amount: 35)
	item_requirement_two.save

	## add this item to that report.
	## i can do that manually

  end

end
