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

	item_type_one = ItemType.new(name: "Golden Top Tube")
	item_type_one.save

	item_type_two = ItemType.new(name: "RS Tube")
	item_type_two.save

	item_type_three = ItemType.new(name: "Plain Tube")
	item_type_three.save

	item_type_four = ItemType.new(name: "Plasma Tube")
	item_type_four.save

	item_requirement = ItemRequirement.new(name: "Golden Top Tube", item_type: item_type_one.name, optional: "yes", priority: 1, amount: 50)
	item_requirement.save

	item_requirement_two = ItemRequirement.new(name: "RS Tube", item_type: item_type_two.name, optional: "no", priority: 1, amount: 35)
	item_requirement_two.save

	item_requirement_three = ItemRequirement.new(name: "Plain Tube", item_type: item_type_three.name, optional: "yes", priority: 1, amount: 35)
	item_requirement_three.save

	item_requirement_four = ItemRequirement.new(name: "Plasma Tube", item_type: item_type_four.name, optional: "yes", priority: 1, amount: 35)
	item_requirement_four.save

	## add this item to that report.
	## i can do that manually
	r = Report.new(name: "Creatinine", price: 300)
	r.test_ids = [t.id.to_s,t2.id.to_s]
	r.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
	r.save

	r = Report.new(name: "Urea", price: 300)
	r.test_ids = [t.id.to_s,t2.id.to_s]
	r.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
	r.save

	r = Report.new(name: "HDL", price: 300)
	r.test_ids = [t.id.to_s,t2.id.to_s]
	r.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
	r.save

	item_one = Item.new(item_type: item_type_one.name, barcode: "GOLDEN_TOP_TUBE", expiry_date: (Time.now + 10.days).to_s)
	item_one.save

	item_two = Item.new(item_type: item_type_two.name, barcode: "RS_TUBE", expiry_date: (Time.now.to_s).to_s)
	item_two.save

	item_three = Item.new(item_type: item_type_three.name, barcode: "PLAIN_TUBE", expiry_date: (Time.now.to_s).to_s)
	item_three.save

	item_four = Item.new(item_type: item_type_four.name, barcode: "PLASMA_TUBE", expiry_date: (Time.now.to_s).to_s)
	item_four.save

	## so now we have saved the items, and the optional item requirements.
	## these are for the individual requiremetns.
	## now the first thing is to check why the tube assignment is not working.
	## and the second thing is to check about item_requirement_amounts.

	status_zero = Status.new(name: "At Collection Site", priority: 0)
	status_zero.save

	status_one = Status.new(name: "On Conveyor Belt", priority: 0)
	status_one.save

	status_two = Status.new(name: "In Centrifuge", priority: 1)
	status_two.save

	status_three = Status.new(name: "Waiting For Analyzer", priority: 2)
	status_three.save

	status_four = Status.new(name: "Inside Analyzer", priority: 3)
	status_two.save

	status_five = Status.new(name: "Result Pending Verification", priority: 4)
	status_five.save

	status_six = Status.new(name: "Verified, Waiting for Print", priority: 5)
	status_six.save		

	status_seven = Status.new(name: "Pending Aliquoting for Deep Freeze Storage", priority: 6)
	status_seven.save

	status_eight = Status.new(name: "Aliquoted", priority: 6)
	status_eight.save

	## we will add these statuses to three reports.
	## after this i have to solve the problem of the tube requirements.

	5.times do |n|
		status = Status.new(report_id: "report#{n}", order_id: "order1", numeric_value: 100, name: "bill", priority: 0)
		status.save
	end

	2.times do |n|
		status = Status.new(order_id: "order1", numeric_value: 100, name: "payment", priority: 0)
		status.save
	end

  end

end
