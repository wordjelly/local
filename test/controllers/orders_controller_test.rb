require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  	
  setup do 

  	@t = Test.new(name: "MCV", lis_code: "MCV", price: 100)
	@t.save

	@t2 = Test.new(name: "MCH", lis_code: "MCH", price: 100)
	@t2.save

	@t3 = Test.new(name: "HBA1C", lis_code: "HBA1C", price: 550)
	@t3.save

	
	@patient = Patient.new(first_name: "Bhargav", last_name: "Raut")
	@patient.save

	@item_type_one = ItemType.new(name: "Lavender Tube")
	@item_type_one.save

	
	@item_type_two = ItemType.new(name: "Urine Tube")
	@item_type_two.save

	@item_requirement = ItemRequirement.new(name: "Hemogram Tube", item_type: @item_type_one.name, optional: "no", priority: 1, amount: 50)
	@item_requirement.save

	@item_requirement_two = ItemRequirement.new(name: "Urine Tube", item_type: @item_type_two.name, optional: "no", priority: 1, amount: 35)
	@item_requirement_two.save

	@item_requirement_three = ItemRequirement.new(name: "Hemogram Tube", item_type: @item_type_one.name, optional: "no", priority: 1, amount: 80)
	@item_requirement_three.save

	## make a report.
	@r = Report.new(name: "Hemogram")
	@r.test_ids = [@t.id.to_s,@t2.id.to_s]
	@r.item_requirement_ids = [@item_requirement.id.to_s, @item_requirement_two.id.to_s]
	@r.save

	@r2 = Report.new(name: "HBA1C")
	@r2.test_ids = [@t3.id.to_s]
	@r2.item_requirement_ids = [@item_requirement.id.to_s]
	@r2.save

	@r3 = Report.new(name: "Dengue")
	@r3.test_ids = [@t3.id.to_s]
	@r3.item_requirement_ids = [@item_requirement_three.id.to_s]
	@r3.save
	## so r2 is the second report that needs the same thing.

	@item = Item.new
	@item.barcode = "abcdefgh"
	@item.save

  end

=begin
  test "creates an order with a patient and 3 reports, and generates item requirements" do
   	
    post("/orders.json",{"template_report_ids" => [@r.id.to_s], "patient_id" => @patient.id.to_s})

    #order = Order.find(JSON.parse(response.body)["id"])

  end


  test "updates one tube with barcode" do 

  	@order = Order.new

  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save

  	put("/orders/#{@order.id.to_s}.json","item_requirements"=>{"0"=>{"type"=>"Lavender Tube", "index"=>"0", "barcode"=> @item.barcode}})

    order = Order.find(@order.id.to_s)
    assert_equal @item.barcode,order.item_requirements["Lavender Tube"][0]["barcode"]
  
  end


  test "updates barcoded tube with filled amount" do 

  	@order = Order.new

  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save

  	put("/orders/#{@order.id.to_s}.json","item_requirements"=>{"0"=>{"type"=>"Lavender Tube", "index"=>"0", "barcode"=> @item.barcode, "filled_amount" => "22.5"}})

    order = Order.find(@order.id.to_s)
    assert_equal 22.5,order.item_requirements["Lavender Tube"][0]["filled_amount"]	

  end

  test " on adding a barcode, updates the item post-save" do 

  end
=end
  ########### SCENARIOS OF ADDING REPORTS AND REMOVING REPORTS FROM THE ORDER 
=begin
  test "adds a report to an existing order, that needs a tube type that has already been given a filled amount and a barcode, and the filled amount is sufficient" do 

  	@order = Order.new

  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save
  	#puts "order requirements at this stage are:"
  	#puts @order.item_requirements["Lavender Tube"]
  	
  	o = Order.find(@order.id)
  	#puts o.item_requirements.to_s
  	## this should have been an array., 
  	## not a hash.
  	#exit(1)
  	o.item_requirements["Lavender Tube"][0]["filled_amount"] = 100
  	o.item_requirements["Lavender Tube"][0]["barcode"] = @item.barcode
  	o.save

  	o = Order.find(@order.id)

  	put("/orders/#{@order.id.to_s}.json","template_report_ids" => [@r2.id.to_s])

  	## now we should have got the updated item_requirements.
  	o = Order.find(@order.id)

  	puts o.item_requirements.to_s
  	assert_equal 100, o.item_requirements["Lavender Tube"][0]["required_amount"]
  	## so the lavender tube required amount should be 

  end



  test "adds a report to an existing order, that needs a tube type that exists, but does not have enough filled amount" do 

  	@order = Order.new

  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save
  	#puts "order requirements at this stage are:"
  	#puts @order.item_requirements["Lavender Tube"]
  	
  	o = Order.find(@order.id)
  	#puts o.item_requirements.to_s
  	## this should have been an array., 
  	## not a hash.
  	#exit(1)
  	o.item_requirements["Lavender Tube"][0]["filled_amount"] = 50
  	o.item_requirements["Lavender Tube"][0]["barcode"] = @item.barcode
  	o.save

  	o = Order.find(@order.id)

  	put("/orders/#{@order.id.to_s}.json","template_report_ids" => [@r2.id.to_s])

  	## now we should have got the updated item_requirements.
  	o = Order.find(@order.id)

  	puts o.item_requirements.to_s
  	assert_equal 2, o.item_requirements["Lavender Tube"].size
  	assert_equal 50, o.item_requirements["Lavender Tube"][1]["required_amount"]

  end

=end
=begin
  test "adds a report to an existing order, for an existing tube type, without a barcode and without a filled amount, where the required amount does not exceed max tube capacity " do 


  	@order = Order.new
  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save
  

  	put("/orders/#{@order.id.to_s}.json","template_report_ids" => [@r2.id.to_s])

  	o = Order.find(@order.id)

  	puts o.item_requirements.to_s
  	assert_equal 1, o.item_requirements["Lavender Tube"].size
  	assert_equal 100, o.item_requirements["Lavender Tube"][0]["required_amount"]


  end

  test "adds a report to an existing order, for an existing tube type, without a barcode and without a filled amount, where the required amount exceeds max tube capacity" do

  	@order = Order.new

  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save

  	put("/orders/#{@order.id.to_s}.json","template_report_ids" => [@r3.id.to_s])

  	
  	o = Order.find(@order.id)

  	puts o.item_requirements.to_s
  	assert_equal 2, o.item_requirements["Lavender Tube"].size
  	assert_equal 80, o.item_requirements["Lavender Tube"][1]["required_amount"]


  end

  test "adds the patient report id to the item_requirement" do 

  	@order = Order.new

  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save

  	put("/orders/#{@order.id.to_s}.json","template_report_ids" => [@r3.id.to_s])

  	o = Order.find(@order.id)

  end
=end
=begin
  test "if another order has the barcode it will provide a relevant error" do 

  	@order = Order.new
  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save
  	
  	o = Order.find(@order.id)
  	
  	o.item_requirements["Lavender Tube"][0]["filled_amount"] = 50
  	o.item_requirements["Lavender Tube"][0]["barcode"] = @item.barcode
  	o.item_ids << @item.barcode

  	o.save

  	## now create a new order for the same patient.
  	## and try adding these as barcodes.
  	order_two = Order.new
  	order_two.patient_id = @patient.id.to_s
  	order_two.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	order_two.save

  	put("/orders/#{order_two.id.to_s}.json","item_requirements"=>{"0"=>{"type"=>"Lavender Tube", "index"=>"0", "barcode"=> @item.barcode, "filled_amount" => "22.5"}})

  	## this should not get saved.
  	order_two = Order.find(order_two.id.to_s)
  	puts "requirements of order two."
  	puts order_two.item_requirements.to_s
  	assert_equal nil, order_two.item_requirements["Lavender Tube"][0]["barcode"]
  	assert_equal [], order_two.item_ids

  end


  test "cannot update non barcoded tube with filled amount" do 

  	@order = Order.new
  	@order.patient_id = @patient.id.to_s
  	@order.add_remove_reports({template_report_ids: [@r.id.to_s]})
  	@order.save
  	
  	o = Order.find(@order.id)

	 put("/orders/#{o.id.to_s}.json","item_requirements"=>{"0"=>{"type"=>"Lavender Tube", "index"=>"0","filled_amount" => "22.5"}})  	

	 o = Order.find(@order.id)

	 assert_equal nil, o.item_requirements["Lavender Tube"][0]["barcode"]
	 assert_equal 0, o.item_requirements["Lavender Tube"][0]["filled_amount"]
  	assert_equal [], o.item_ids

  end
=end
  test " removes the report from the report ids, and item requirements " do 


    @order = Order.new
    @order.patient_id = @patient.id.to_s
    @order.add_remove_reports({template_report_ids: [@r.id.to_s]})
    @order.save
    
    put("/orders/#{@order.id.to_s}.json","template_report_ids" => [])    

    o = Order.find(@order.id)

    puts "template report ids---------"
    puts o.template_report_ids.to_s

    puts "patient report ids-----------"
    puts o.patient_report_ids

    puts "patient test ids ------------"
    puts o.patient_test_ids

    puts "item requirements ------------"
    puts o.item_requirements
    #assert_equal {}, o.item_requirements
    #assert_equal [], o.template_report_ids
    #assert_equal [], o.patient_report_ids
    #assert_equal [], o.patient_test_ids


  end

  ## item group can have any number of containers.
  ## it is not only tubes.
  ## but it has to have an item type.
  ## so it can have any number of items ?
  ## so we have to first create items.

=begin
  test "if filled amount is insufficient, marks the tube as QNS" do 
  	## on updating the filled amount, it will check if this is more than or equal to the required amount, and mark as quantity not sufficient.

  end
=end
  ######
  ## WRONG BARCODE WAS ENTERED FOR A TUBE 
  ######

  #####
  ## WRONG ITEM GROUP WAS ENTERED FOR A TUBE
  #####

  ######
  ## 
  ######

  #####
  ## ADDED A TEST AND COLLECTION IS NO LONGER POSSIBLE
  #####

=begin
  test "removes a barcode from a tube" do 

  end

  test "updates created order with item group" do 

  end

  test "adds two reports to an already existing order" do 
	## we have to test all the scenarios
  end
=end

  ## test group for lab using a mix of barcoded and non-barcoded samples.
  ## do they use their own barcodes or our barcodes?
  ## 

end