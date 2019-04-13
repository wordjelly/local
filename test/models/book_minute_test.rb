require 'test_helper'
 
class BookMinuteTest < ActiveSupport::TestCase

	setup do 

		["Test","Employee","Item","ItemGroup","ItemRequirement","ItemType","Location","NormalRange","Order","Patient","Report","Status","Test","Image","Minute"].each do |cls|
	        cls.constantize.send("create_index!",{force: true})
	    end
		
		## or we can have those usual item_requirements.
		###################
	    ##
	    ## TESTS
	    ##
	    ###################
      	t = Test.new(name: "MCV", lis_code: "MCV", price: 100)
      	t.save

      	t2 = Test.new(name: "MCH", lis_code: "MCH", price: 100)
      	t2.save


      	###################
      	##
      	## PATIENT
      	##
      	###################
      	patient = Patient.new(first_name: "Bhargav", last_name: "Raut")
      	patient.save


      	###################
      	##
      	## ITEM TYPE
      	##
      	###################
      	item_type_one = ItemType.new(name: "Serum Tube")
      	item_type_one.save


      	###################
      	##
      	## ITEM REQUIREMENT
      	##
      	###################
      	item_requirement = ItemRequirement.new(name: "Golden Top Tube", item_type: item_type_one.name)
	    item_requirement.save

	    item_requirement_two = ItemRequirement.new(name: "RS Tube", item_type: item_type_one.name)
	    item_requirement_two.save

	    item_requirement_three = ItemRequirement.new(name: "Plain Tube", item_type: item_type_one.name)
	    item_requirement_three.save


	    ####################
	    ##
	    ## REPORTS
	    ##
	    ####################
	    r1 = Report.new(name: "Creatinine", price: 300)
	    r1.test_ids = [t.id.to_s,t2.id.to_s]
	    r1.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s]
	    r1.save
	    @r1_id = r1.id.to_s

	    r2 = Report.new(name: "Urea", price: 300)
	    r2.test_ids = [t.id.to_s,t2.id.to_s]
	    r2.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s]
	    r2.save
	    @r2_id = r2.id.to_s

	    r3 = Report.new(name: "HDL", price: 300)
	    r3.test_ids = [t.id.to_s,t2.id.to_s]
	    r3.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s]
	    r3.save
	    @r3_id = r3.id.to_s


	    ###############################
	    ##
	    ## ITEM REQUIREMENT DEFINITIONS
	    ##
	    ###############################

	    [item_requirement,item_requirement_two,item_requirement_three].each_with_index {|ir,key|
        item_requirement = ItemRequirement.find(ir.id.to_s)
        	item_requirement.definitions = 
        	[
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

	    item_one = Item.new(item_type: "Golden Top Tube", barcode: "Golden Top Tube", expiry_date: (Time.now + 10.days).to_s)
      	item_one.save

      	item_one_b = Item.new(item_type: "Golden Top Tube", barcode: "Golden Top Tube 2", expiry_date: (Time.now + 10.days).to_s)
      	item_one_b.save

      	item_two = Item.new(item_type: "RS Tube", barcode: "RS Tube", expiry_date: (Time.now.to_s).to_s)
      	item_two.save

      	item_three = Item.new(item_type: "Plain Tube", barcode: "Plain Tube", expiry_date: (Time.now.to_s).to_s)
      	item_three.save

      	## we have to provide a duration and maximum capacity.
      	@status_zero = Status.new(name: "At Collection Site", priority: 0, parent_ids: [@r1_id, @r2_id, @r3_id])
	    @status_zero.save

	    
	end

=begin
	test "books single minute" do 

		Minute.create_index! force: true
		Minute.create_single_test_minute(@status_zero)

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

	    puts " - setup completed - "

		o = Order.new
	    o.patient_id = "test_patient"
	    o.template_report_ids = [@r1_id,@r2_id,@r3_id]
	    o.start_time = Time.utc(1970,1,1,0,0,0)
	    if o.errors.empty?
	      puts "SAVING ORDER IT HAS NO ERRORS."
	     # o.run_callbacks(:save)
	      response = o.save
	      puts o.errors.full_messages.to_s
	      puts response.to_s

	    else
	      puts " ORDER HAS ERRORS "
	    end

	    m = Minute.find("1")
	    ## its bookings should not be empty.
	    assert m.employees[0]["bookings"].size == 1

	end
=end

=begin
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

	    o.tubes.each do |tube|
	   		Minute.update_tube_barcode(tube["patient_report_ids"],tube["item_requirement_name"])
	  	end
=end

	test "uses existing order status if it is available" do 

		Minute.create_index! force: true
		Minute.create_single_test_minute(@status_zero,2)

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

	    puts " - setup completed - "

		o = Order.new
	    o.patient_id = "test_patient"
	    o.template_report_ids = [@r1_id,@r2_id]
	    o.start_time = Time.utc(1970,1,1,0,0,0)
	    if o.errors.empty?
	      puts "SAVING ORDER IT HAS NO ERRORS."
	     # o.run_callbacks(:save)
	      response = o.save
	      puts o.errors.full_messages.to_s
	      puts response.to_s

	    else
	      puts " ORDER HAS ERRORS "
	    end

	    #exit(1)
	    ## so basically we have to see it working, even when reports are available
	    ## for other employees
	    ## and the same employee.
	    ## so lets have one more employee.

	    o = Order.find(o.id.to_s)
	    o.patient_id = "test_patient"
	    o.template_report_ids = [@r1_id,@r2_id,@r3_id]
		o.start_time = Time.utc(1970,1,1,0,0,0)
	    if o.errors.empty?
	      puts "SAVING ORDER IT HAS NO ERRORS."
	     # o.run_callbacks(:save)
	      response = o.save
	      puts o.errors.full_messages.to_s
	      puts response.to_s

	    else
	      puts " ORDER HAS ERRORS "
	    end	    

	    ## so it has merged this order.
	    ## why ?
	    ## because the status matches.
	    ## but within only one minute.
	    ## now lets do a test
	    ## where it has to do three different statuses
	    ## each about 10 minutes long.
	    ## and then see how things go, over 60 minutes
	    ## lets keep two employees.
	    ## first solve the null problems.
	end

=begin
	test "books two minutes" do 
	
	end

	test "scheduling fails, if a status cannot be satisfied" do 
	
	end

	test "updates barcodes" do 

	end

	test "tries another order time" do 

	end

	test "adds reports to order, updates barcodes simultaneously" do 
		## will add some statuses to existing status
		## and new ones to newer entries.
	end

	test "removes reports from order, updates barcodes simultaneously" do 

	end

	test "blocks other employees for centrifuge" do 

	end


	test "blocks same employee for centrifuge" do 

	end
=end
	
	
end