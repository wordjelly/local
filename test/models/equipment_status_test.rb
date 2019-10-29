require 'test_helper'
 

class EquipmentStatusTest < ActiveSupport::TestCase
   
    setup do 

    	["Test","Employee","Item","ItemGroup","ItemRequirement","ItemType","Location","NormalRange","Order","Patient","Report","Status","Test","Image"].each do |cls|
      	  cls.constantize.send("create_index!",{force: true})
	    end

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

      	## okay so we got the report ids.
      	## now what ?
      	## we want to gather statuses, for any of those reports.
      	## either patient or template.
      	## since the report will have both status and template report ids.
      	## 
      	## so now come the statuses.
      	## we have to set those parent ids.
      	## with the priorities
      	## and then we aggregate by item
      	## first we have to assign those items to the order.
      	## then go for statuses.
      	@status_zero = Status.new(name: "At Collection Site", priority: 0, parent_ids: [@r1_id, @r2_id, @r3_id])
	    @status_zero.save

      	@status_one = Status.new(name: "On Conveyor Belt", priority: 0, parent_ids: [@r1_id, @r2_id, @r3_id])
      	@status_one.save

	    @status_two = Status.new(name: "In Centrifuge", priority: 1, parent_ids: [@r1_id, @r2_id, @r3_id])
	    @status_two.save

	    @status_three = Status.new(name: "Waiting For Analyzer", priority: 2, parent_ids: [@r1_id, @r2_id, @r3_id])
	    @status_three.save

	    @status_four = Status.new(name: "Inside Analyzer", priority: 3, parent_ids: [@r1_id, @r2_id, @r3_id])
	    @status_two.save

	    @status_five = Status.new(name: "Result Pending Verification", priority: 4, parent_ids: [@r1_id, @r2_id, @r3_id])
	    @status_five.save

	    Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

    end

	test " looking for a barcode, gives the statuses of each report under that item -- " do 

	  	o = Order.new
	  	o.start_time = Time.now
	  	o.patient_id = "test_patient"
	  	o.template_report_ids = [@r1_id,@r2_id,@r3_id]
	  	if o.errors.empty?
	  		puts "------ first save completed-----------"
	    	o.save
	  	end

	  	k = o.tubes
	  	k[0]["barcode"] = "Golden Top Tube"
	  	k[1]["barcode"] = "RS Tube"
	  	k[2]["barcode"] = "Plain Tube"

	    o = Order.find(o.id.to_s)
	    o.tubes = k
	    o.template_report_ids = [@r1_id,@r2_id,@r3_id]
	    if o.errors.empty?
	    	puts "- =================saved order============="
	        o.save
	    else
	    	puts 
	    end

      	o.tubes.first["patient_report_ids"].each_with_index {|pid,key|
      	
      		template_report_id = o.tubes.first["template_report_ids"][key]
      	
	      	if key == 0
		      	
		      	[@status_one, @status_two, @status_three, @status_four, @status_five].each do |st|
		      		status = Status.new(st.attributes.except(:id))
		      		status.parent_ids = [pid,template_report_id]
		      		status.save
		      	end

	      	end

	      	if key == 1

	      		[@status_one, @status_two, @status_three].each do |st|
	      			status = Status.new(st.attributes.except(:id))
		      		status.parent_ids = [pid,template_report_id]
		      		status.save
	      		end

	      	end
      	}

      	#reports_to_statuses_hash = Status.get_statuses_for_report_ids(o.tubes.first["template_report_ids"])

      	#puts JSON.pretty_generate(reports_to_statuses_hash)

      	#now i want to call gather_statuses with no arguments.
      	#Status.gather_statuses
      	#employee schedule management + absentees + rotations.
      	#including recurring job management.
      	Status.gather_statuses
	end
end