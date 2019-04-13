require 'test_helper'
 
class MinuteTest < ActiveSupport::TestCase
   
    setup do
		Minute.create_index! force: true    	
		Minute.create_test_minutes(25)
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
    end


    ## what all to test
    ## 

    test "test adds new employee to minute" do 
    	new_employee_ids = ["101","221","321"]

		update_hash = Minute.update_minute("1",{
    		employee_ids: new_employee_ids,
    		status_id: "1"
    	})		
    	Minute.add_bulk_item(update_hash)
    	Minute.flush_bulk
    	Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"

    	minute = Minute.find("1")
    	selected_minutes = minute.employees.select{|c|
    		new_employee_ids.include? c["id"]
    	}
    	assert_equal 3, selected_minutes.size
    end

    test "adds status id to existing employee" do 
    	new_employee_ids = ["101","221","321"]

		update_hash = Minute.update_minute("2",{
    		employee_ids: new_employee_ids,
    		status_id: "1"
    	})		
    	Minute.add_bulk_item(update_hash)
    	Minute.flush_bulk
    	Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"

    	## now we update the same employees in this minute, with another status id.
    	new_employee_ids = ["101","221","321"]

		update_hash = Minute.update_minute("2",{
    		employee_ids: new_employee_ids,
    		status_id: "1000"
    	})		
    	Minute.add_bulk_item(update_hash)
    	Minute.flush_bulk
    	Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"

    	## now this minute, should have employees with both these status ids.

    	m = Minute.find("2")
    	selected_employees = m.employees.select{|c|
    		new_employee_ids.include? c["id"]
    	}

    	assert_equal 3, selected_employees.size

    	selected_employees.each do |employee|
    		assert_equal ["1","1000"], employee["status_ids"]
    	end

    end

    test " - gets all minutes as slots for this status - " do 

		required_statuses = [
			{
				:from => 0,
				:to => 10,
				:id => "1",
				:maximum_capacity => 10
			}
		]

		statuses_hash = Minute.get_minute_slots({:required_statuses => required_statuses, :order_id => "test"})

		[0,1,2,3,4,5,6,7,8,9].each do |n|
			
			assert statuses_hash["1"][n.to_s]
			[0,1,2,3,4,5].each do |emp_id|
				assert statuses_hash["1"][n.to_s]["-1"].include? emp_id.to_s
			end
		end
		
	end

	## so here we work on get slots.
	## then we move to the schedule scenarios.

=begin
    test "aggregates the bookings of the employee to be blocked" do 
    	Minute.aggregate_employee_bookings("1","","")
    end
=end
	
=begin
	
=end
	

=begin
	test "single minute, single report, single status, single order" do 
		
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

	    Minute.create_index! force: true
		Minute.create_single_test_minute(@status_zero)

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
	    ## now we have to make the order.
	    ## 
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

	    #m = Minute.find("1")
	    #puts JSON.pretty_generate(m.attributes)

	end
=end

=begin
	test "two minutes, single report, single status, single order, should block employee in subsequent minute, by raising bookings score" do 

		
	    ## now we have to make the order.
	    ## 
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

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

	    o.tubes.each do |tube|
	   		Minute.update_tube_barcode(tube["patient_report_ids"],tube["item_requirement_name"])
	  	end
	end
=end


=begin
	test " doesnt find any employee for some particular status somewhere in the chain -- " do 

		## in this case, for that status we have nothing.
		## it will directly jump to the next status.
		## so what to do ?
		## this status gets piggybacked to whichever employee did the last status.
		## so it will cause a delay / disruption.
		## the question is that if it doesn't find anythign for the first status itself ?
		## in that case what to do  ?
		## we choose as wide a range as possible, but then 
		## it has to notify, saying please choose another start time.
		## so when we set the minute updates, we have to have all the statuses, one after the other.
		## 

	end

	test " adds tubes to bookings -- " do 
			
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

	    Minute.create_index! force: true
		Minute.create_two_test_minutes(@status_zero)

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
	    ## now we have to make the order.
	    ## 
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

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

	    o.tubes.each do |tube|
	   		Minute.update_tube_barcode(tube["patient_report_ids"],tube["item_requirement_name"])
	  	end
		
	end
=end

=begin
    test "blocks employee given start time and end time" do

    end

    test "reallots job to other employee if primary employee is to be blocked" do 

    end

	test "doesnt find anyone to reallot the job to " do 

	end


	test "machine capacity is obeyed" do 

	end
	
	test "two employees don't get allocated to the same machine at the same time" do 

	end


	
=end

end