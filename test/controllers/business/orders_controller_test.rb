require "test_helper"
require "helpers/test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest

    include TestHelper
    
    setup do

        _setup

    end

    ## first let me get these tests to pass
    ## and then we can move forwards
    ## to range interpretation and order accessibility
    ## 

=begin
    test " -- creates an order with multiple reports -- " do 

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"


        order = build_plus_path_lab_patient_order

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "201", response.code.to_s

        order = Business::Order.new(JSON.parse(response.body)["order"])

        assert_equal true, !order.categories.blank?

    end
=end


=begin
    test " -- on adding an item, updates to all relevant reports, and reduces required quantities of all other categories --" do 

        ## so basically that item did not exist.
        ## and it failed miserably.

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = create_plus_path_lab_patient_order
        
        order = Business::Order.find(order.id.to_s)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        #puts plus_lab_employee.organization_members[0].organization_id


        organization_items = Inventory::Item.find_organization_items(plus_lab_employee.organization_members[0].organization_id)

        #puts organization_items.to_s
       
        #exit(1)

        order.categories[0].items.push(organization_items.first)

        first_category_name = order.categories[0].name

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)
        
        #k = JSON.parse(response.body)
        #puts k["errors"]

        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"                 

        order = Business::Order.find(order.id.to_s)

        found_item = false

        order.reports.each do |report|
            report.requirements.each do |requirement|
                requirement.categories.each do |category|
                    #puts "category name is: #{category.name}"
                    #puts "category items are:"
                    #puts category.items.to_s
                    #so its not updating
                    if category.name == first_category_name
                        found_item = true
                        assert_equal 1, category.items.size
                    end
                end     
            end 
        end     

        # not getting added to reports.
        assert_equal true, found_item

    end
=end


    test " - picks range according to age, both normal and abnormal - " do 

    end

=begin
    test " - if a test has a required history question, then does not go forward till that is answered -- " do 

    end


    test " - picks the range as per the history answer(Textual) - " do 

    end


    test " - picks the range as per the history answer(numeric) - " do 

    end

    test " - if multiple histories are there, picks the combined range -- " do 

    end
=end


    ## so if it works till here it is enough.
    ## the next step will be 

=begin
    test " -- collates the various reports by commonality of the procedure -- " do 

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        status = Diagnostics::Status.new(name: "one", description: "step one") 
        test = Diagnostics::Test.new(name: "MCV", description: "Mean Corpuscular Volume", price: 20, lis_code: "MCV")     
        requirement = Inventory::Requirement.new
        category = Inventory::Category.new(name: "rapid serum tube", quantity: 10)
        
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "blank name"
        report.description = "new report description"
        
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_one_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        ## now add another one.
        status = Diagnostics::Status.new(name: "one", description: "step one") 
        test = Diagnostics::Test.new(name: "Vitamin D", description: "Vitamin D level in blood", price: 20, lis_code: "VITD")     
        requirement = Inventory::Requirement.new
        category = Inventory::Category.new(name: "serum tube", quantity: 10)
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "25, OH dihydroxy vitamin d"
        report.description = "Measurement of Vitamin D"
        0
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        report_two = Diagnostics::Report.find(report_two_id)


        report_one.start_epoch = 450
        report_two.start_epoch = 100
        

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        
    
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers

    end

    
    test " -- first collates reports by start time, then by the commonality of procedure -- " do 



    end
=end

=begin
    test " -- doess query and block aggregation -- " do 
        ## so now we create fewer test minutes
        ## it should ignore the employee and for status ids 
        ## as required.
        status_ids = ["step 1","step 2","step 3","step 4","step 5","step 6","step 7","step 8","step 9","step 10"]
        Schedule::Minute.create_test_minutes
       
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"


        status = Diagnostics::Status.new(name: status_ids[0], description: "step one") 
        test = Diagnostics::Test.new(name: "MCV", description: "Mean Corpuscular Volume", price: 20, lis_code: "MCV")     
        requirement = Inventory::Requirement.new
        category = Inventory::Category.new(name: "rapid serum tube", quantity: 10)
        
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = status_ids.map{|c| 
            s = Diagnostics::Status.new
            s.name = c
            s.duration = 20
            s.description = c
            s.origin = {lat: 10, lon: 10}
            s
        }
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "blank name"
        report.description = "new report description"
        
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_one_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        ## now add another one.
        status = Diagnostics::Status.new(name: status_ids[0], description: "step one") 
        test = Diagnostics::Test.new(name: "Vitamin D", description: "Vitamin D level in blood", price: 20, lis_code: "VITD")     
        requirement = Inventory::Requirement.new
        category = Inventory::Category.new(name: "serum tube", quantity: 10)
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = status_ids.map{|c| 
            s = Diagnostics::Status.new
            s.name = c
            s.duration = 10
            s.description = c
            s.origin = {lat: 10, lon: 10}
            s
        }
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "25, OH dihydroxy vitamin d"
        report.description = "Measurement of Vitamin D"
        0
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        report_two = Diagnostics::Report.find(report_two_id)

        report_one.start_epoch = 450
        report_two.start_epoch = 100

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers     
      
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           
        
        order_one = Business::Order.find(JSON.parse(response.body)["order"]["id"])

        #exit(1)

        #puts JSON.pretty_generate(order_one.get_schedule)
        ## okay so we just want to see if the blocks work or not

        #post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers     

        puts " ----------- STARTING ORDER TWO ------------------ "

        order_two = Business::Order.new
        order_two.reports = [report_one,report_two]
        order_two.created_by_user = @u
        order_two.created_by_user_id = @u.id.to_s
        order_two.name = "second order"
        order_two.save
        #puts order_two.errors.full_messages.to_s

        assert_equal true, order_two.errors.full_messages.blank?


        #puts response.body.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           


        order_two = Business::Order.find(order_two.id.to_s)

       # puts JSON.pretty_generate(order_two.get_schedule)
            

    end


    test " -- generates queries and blocks hash -- " do 

        #status_ids = ["step 1","step 2","step 3"]
        
        status_ids_report_one = ["step 1","step 2","step 3"]
        
        status_ids_report_two = ["step 4","step 5","step 6"]

        Schedule::Minute.create_test_minutes
       
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        #status = Diagnostics::Status.new(name: status_ids[0], description: "step one") 

        test = Diagnostics::Test.new(name: "MCV", description: "Mean Corpuscular Volume", price: 20, lis_code: "MCV")     
        requirement = Inventory::Requirement.new
        
        category = Inventory::Category.new(name: "rapid serum tube", quantity: 10)
        
        requirement.categories = [category]
        
        report = Diagnostics::Report.new
        
        report.statuses = status_ids_report_one.map{|c| 
            s = Diagnostics::Status.new
            s.name = c
            s.duration = 20
            s.description = c
            s.origin = {lat: 10, lon: 10}
            s
        }

        report.tests = [test]
        
        report.requirements = [requirement]
        
        report.name = "blank name"
        
        report.description = "new report description"
        
        
        
        report.created_by_user = @u
        
        report.created_by_user_id = @u.id.to_s
        
        report.assign_id_from_name
        
        report.save
        
        assert_equal true, report.errors.full_messages.blank?

        report_one_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        ## now add another one.
        #status = Diagnostics::Status.new(name: status_ids[0], description: "step one") 
        
        test = Diagnostics::Test.new(name: "Vitamin D", description: "Vitamin D level in blood", price: 20, lis_code: "VITD")     
        
        requirement = Inventory::Requirement.new
        
        category = Inventory::Category.new(name: "serum tube", quantity: 10)
        
        requirement.categories = [category]
        
        report = Diagnostics::Report.new
        
        report.statuses = status_ids_report_two.map{|c| 
            s = Diagnostics::Status.new
            s.name = c
            s.duration = 10
            s.description = c
            s.origin = {lat: 10, lon: 10}
            s
        }
        
        report.tests = [test]
        
        report.requirements = [requirement]
        
        report.name = "25, OH dihydroxy vitamin d"
        
        report.description = "Measurement of Vitamin D"
        
        0
        
        report.created_by_user = @u
        
        report.created_by_user_id = @u.id.to_s
        
        report.assign_id_from_name
        
        report.save
        
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        report_two = Diagnostics::Report.find(report_two_id)

        report_one.start_epoch = 450
        report_two.start_epoch = 450

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers     
      
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           
        
        order_one = Business::Order.find(JSON.parse(response.body)["order"]["id"])

    end
=end


end