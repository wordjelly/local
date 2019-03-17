namespace :db do
  desc "Creates two dummy tests, one report containing those tests and one patient"
  task seed: :environment do
  	
  	["Test","Employee","Item","ItemGroup","ItemRequirement","ItemType","Location","NormalRange","Order","Patient","Report","Status","Test"].each do |cls|
  		cls.constantize.send("create_index!",{force: true})
  	end

  	t = Test.new(name: "MCV", lis_code: "MCV", price: 100)
	t.save

	t2 = Test.new(name: "MCH", lis_code: "MCH", price: 100)
	t2.save

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
	r = Report.new(name: "Hemogram")
	r.test_ids = [t.id.to_s,t2.id.to_s]
	r.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s]
	r.save

	item_one = Item.new(item_type: item_type_one.name, barcode: "123", expiry_date: (Time.now + 10.days).to_s)
	item_one.save

	item_two = Item.new(item_type: item_type_two.name, barcode: "456", expiry_date: (Time.now.to_s).to_s)
	item_two.save

	status_one = Status.new(name: "On Conveyor Belt")
	status_one.save

	status_two = Status.new(name: "In Centrifuge")
	status_two.save

	5.times do |n|
		status = Status.new(report_id: "report#{n}", order_id: "order1", numeric_value: 100, name: "bill")
		status.save
	end

	2.times do |n|
		status = Status.new(order_id: "order1", numeric_value: 100, name: "payment")
		status.save
	end

  end

end
