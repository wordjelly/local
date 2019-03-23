namespace :db do
	
  desc "Creates two dummy tests, one report containing those tests and one patient"
  task seed: :environment do
  	
  	["Test","Employee","Item","ItemGroup","ItemRequirement","ItemType","Location","NormalRange","Order","Patient","Report","Status","Test","Image"].each do |cls|
  		cls.constantize.send("create_index!",{force: true})
  	end

  	t = Test.new(name: "MCV", lis_code: "MCV", price: 100)
	t.save

	t2 = Test.new(name: "MCH", lis_code: "MCH", price: 100)
	t2.save

	patient = Patient.new(first_name: "Bhargav", last_name: "Raut")
	patient.save

	item_type_one = ItemType.new(name: "Serum Tube")
	item_type_one.save

	item_type_two = ItemType.new(name: "Plasma Tube")
	item_type_two.save

	item_type_three = ItemType.new(name: "Plain Tube")
	item_type_three.save

	item_type_four = ItemType.new(name: "Plasma Tube")
	item_type_four.save

	item_requirement = ItemRequirement.new(name: "Golden Top Tube", item_type: item_type_one.name)
	item_requirement.save

	item_requirement_two = ItemRequirement.new(name: "RS Tube", item_type: item_type_one.name)
	item_requirement_two.save

	item_requirement_three = ItemRequirement.new(name: "Plain Tube", item_type: item_type_one.name)
	item_requirement_three.save

	item_requirement_four = ItemRequirement.new(name: "Plasma Tube", item_type: item_type_two.name)
	item_requirement_four.save

	## add this item to that report.
	## i can do that manually
	r1 = Report.new(name: "Creatinine", price: 300)
	r1.test_ids = [t.id.to_s,t2.id.to_s]
	r1.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
	r1.save

	r2 = Report.new(name: "Urea", price: 300)
	r2.test_ids = [t.id.to_s,t2.id.to_s]
	r2.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
	r2.save

	r3 = Report.new(name: "HDL", price: 300)
	r3.test_ids = [t.id.to_s,t2.id.to_s]
	r3.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
	r3.save

	[item_requirement,item_requirement_two,item_requirement_three].each_with_index {|ir,key|
		item_requirement = ItemRequirement.find(ir.id.to_s)
		item_requirement.definitions = [
			{
				report_id: r1.id.to_s,
				report_name: r1.name.to_s,
				amount: 10,
				priority: key
			},
			{
				report_id: r2.id.to_s,
				report_name: r2.name.to_s,
				amount: 10,
				priority: key
			},
			{
				report_id: r3.id.to_s,
				report_name: r3.name.to_s,
				amount: 10,
				priority: key
			}
		]
		item_requirement.save
	}


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
