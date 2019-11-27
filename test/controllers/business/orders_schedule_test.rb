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