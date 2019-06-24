require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest

	setup do 
		Organization.create_index! force: true
		#NormalRange.create_index! force: true
        Diagnostics::Report.create_index! force: true
		Tag.create_index! force: true
		Barcode.create_index! force: true
		Inventory::ItemType.create_index! force: true
		Inventory::ItemGroup.create_index! force: true
		Inventory::Item.create_index! force: true
		Inventory::Transaction.create_index! force: true
		Inventory::ItemTransfer.create_index! force: true
		Inventory::Comment.create_index! force: true
        Schedule::Minute.create_index! force: true
		## that's the end of it
		User.delete_all
		User.es.index.delete
		User.es.index.create
        Auth::Client.delete_all
        #########################################################
        ##
        ##
        ## PATHOFAST USERS
        ##
        ##
        #########################################################
        @u = User.new(email: "bhargav.r.raut@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @u.save
        @u = User.find(@u.id.to_s)
        @u.confirm
        @u.save
        @u2 = User.new(email: "icantremember111@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @u2.save
        @u2 = User.find(@u2.id.to_s)
        @u2.confirm
        @u2.save
		@c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        @u2.client_authentication["testappid"] = "test_es_token_two"
        @u2.save
        @ap_key = @c.api_key

        #########################################################
        ##
        ##
        ## ROLES
        ## controls also have to be established in diagnostics
        ## at the level of the test object.
        ##
        #########################################################
        @pathologist_role = Tag.new(name: "Pathologist",created_by_user: @u, tag_type: Tag::EMPLOYEE_TAG)
        @pathologist_role.assign_id_from_name
		@pathologist_role.save
		#puts "these are the pathologist role error messages ------------------"
		#puts @pathologist_role.errors.full_messages.to_s
		
		#puts Tag.find("Pathologist")
		
		#exit(1)


		@technician_role = Tag.new(name: "Technician", created_by_user: @u, tag_type: Tag::EMPLOYEE_TAG)
		@technician_role.assign_id_from_name
		@technician_role.save

        ##########################################################
        ##
        ##
        ##
        ## KONDHWA DIAGNOSTIC USERS
        ##
        ##
        ##########################################################
        @atif = User.new(email: "atif@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @atif.save
        @atif = User.find(@atif.id.to_s)
        @atif.confirm
        @atif.save
        @atif.client_authentication["testappid"] = "test_es_token_three"
        @atif.save
        @atif.employee_role_id = "Pathologist"
        @atif.save
        ##########################################################

        puts "-------------- DOING PATHAN ----------------------- "
        @pathan = User.new(email: "pathan@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @pathan.save
        @pathan = User.find(@pathan.id.to_s)
        @pathan.confirm
        @pathan.save
        @pathan.client_authentication["testappid"] = "test_es_token_four"
        @pathan.employee_role_id = "Technician"
        @pathan.save
        #puts @pathan.errors.full_messages.to_s
        #exit(1)


        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		@headers = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @u.authentication_token, "X-User-Es" => @u.client_authentication["testappid"], "X-User-Aid" => "testappid"}

        @pathofast = Organization.new(name: "pathofast diagnostic laboratory", description: "new lab", phone_number: "123345", address: "jome")
        @pathofast.role = "lab"
        @pathofast.verifiers = 2
        @pathofast.description = "dog"
        @pathofast.created_by_user_id = @u.id.to_s
        @pathofast.created_by_user = @u
        @pathofast.assign_id_from_name
        @pathofast.save
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        @u = User.find(@u.id.to_s)


        @pathan_headers = {
            "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @pathan.authentication_token, "X-User-Es" => @pathan.client_authentication["testappid"], "X-User-Aid" => "testappid"
        }



    end

=begin

    test " -- creates an order with multiple reports -- " do 

        ## okay now we use json for this ?
        ## 

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        status = Diagnostics::Status.new(name: "one", description: "step one") 
        test = Diagnostics::Test.new(name: "MCV", description: "Mean Corpuscular Volume", price: 20, lis_code: "MCV")     
        requirement = Inventory::Requirement.new(quantity: 10)
        category = Inventory::Category.new(name: "serum tube")
        item = Inventory::Item.new(local_item_group_id: "1234")
        category.items = [item]
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "blank name"
        report.description = "new report description"
        report.price = 52
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
        requirement = Inventory::Requirement.new(quantity: 10)
        category = Inventory::Category.new(name: "serum tube")
        item = Inventory::Item.new(local_item_group_id: "1234")
        category.items = [item]
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "25, OH dihydroxy vitamin d"
        report.description = "Measurement of Vitamin D"
        report.price = 520
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        #puts "the report one requirements are:"
        #puts report_one.requirements.to_s
        #exit(1)

        report_two = Diagnostics::Report.find(report_two_id)

        order = Business::Order.new
        order.reports =  [report_one.attributes,report_two.attributes]
      
        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers 


        assert_equal "201", response.code.to_s

    end


    test " -- collates individual report requirements into order requirements -- " do 

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        status = Diagnostics::Status.new(name: "one", description: "step one") 
        test = Diagnostics::Test.new(name: "MCV", description: "Mean Corpuscular Volume", price: 20, lis_code: "MCV")     
        requirement = Inventory::Requirement.new
        category = Inventory::Category.new(name: "serum tube", quantity: 10)
        item = Inventory::Item.new(local_item_group_id: "1234")
        category.items = [item]
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "blank name"
        report.description = "new report description"
        report.price = 52
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
        item = Inventory::Item.new(local_item_group_id: "1234")
        category.items = [item]
        requirement.categories = [category]
        report = Diagnostics::Report.new
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "25, OH dihydroxy vitamin d"
        report.description = "Measurement of Vitamin D"
        report.price = 520
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        #puts "the report one requirements are:"
        #puts report_one.requirements.to_s
        #exit(1)

        report_two = Diagnostics::Report.find(report_two_id)

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        
        #puts order.reports.to_s
        #exit(1)

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers 

        order = Business::Order.new(JSON.parse(response.body)["order"])

        puts "these are the order categories-"

        puts order.categories.to_s

        assert_equal "201", response.code.to_s
        #assert_equal true, !order.requirements.blank?

    end



    test " -- on adding an item, updates to all relevant reports, and reduces required quantities of all other categories --" do 

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
        report.price = 52
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
        report.price = 520
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        report_two = Diagnostics::Report.find(report_two_id)

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        order.created_by_user = @u
        order.created_by_user_id = @u.id.to_s
        order.assign_id_from_name
        order.save
        assert_equal true, order.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        


        order = Business::Order.find(order.id.to_s)
            
        #puts order.categories[0].to_s
        #exit(1)
        order.categories[0].items.push(Inventory::Item.new(barcode: "1234567", local_item_group_id: "abcde"))

        first_category_name = order.categories[0].name

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers 
    
        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"                 

        order = Business::Order.find(order.id.to_s)

        found_item = false

        order.reports.each do |report|
            report.requirements.each do |requirement|
                requirement.categories.each do |category|
                    if category.name == first_category_name
                        found_item = true
                        assert_equal 1, category.items.size
                    end
                end     
            end 
        end     

        assert_equal true, found_item

    end


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
        report.price = 52
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
        report.price = 520
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        report_two = Diagnostics::Report.find(report_two_id)

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        
        
    
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers

    end
=end
    
    test " -- creates test minutes -- " do 
        status_ids = ["step 1","step 2","step 3","step 4","step 5"]
        Schedule::Minute.create_test_minutes
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        status = Diagnostics::Status.new(name: status_ids[0], description: "step one") 
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
        report.price = 52
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
        report.statuses = [status]
        report.tests = [test]
        report.requirements = [requirement]
        report.name = "25, OH dihydroxy vitamin d"
        report.description = "Measurement of Vitamin D"
        report.price = 520
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        assert_equal true, report.errors.full_messages.blank?

        report_two_id = report.id.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"        

        report_one = Diagnostics::Report.find(report_one_id)
        
        report_two = Diagnostics::Report.find(report_two_id)

        report_one.start_epoch = 10
        report_two.start_epoch = 20

        order = Business::Order.new
        order.reports =  [report_one,report_two]
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"           

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers     

        puts "------------------------- response body ------------ "
        puts response.body.to_s

        o = Business::Order.new(JSON.parse(response.body))
        puts o.errors.full_messages.to_s

    end 

end