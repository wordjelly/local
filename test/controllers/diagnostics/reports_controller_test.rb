require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest

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


    test " -- creates a report with status, requirement and test -- " do 
    	
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        ## load the report parameters from json.
        status = Diagnostics::Status.new(name: "one", description: "step one")
        

        test = Diagnostics::Test.new(name: "MCV", description: "Mean Corpuscular Volume", price: 20, lis_code: "MCV")

            
        requirement = Inventory::Requirement.new(quantity: 10)
        category = Inventory::Category.new(name: "serum tube")
        item = Inventory::Item.new(local_item_group_id: "1234")
        category.items = [item]
        requirement.categories = [category]

    	post diagnostics_reports_path, params: {report: {name: "Hemogram", description: "a simple hemogram report", price: 42, statuses: [status], tests: [test], requirements: [requirement]}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

    	puts response.body.to_s

		assert_equal "201", response.code.to_s
    	
    end

    test " -- updates a report -- " do 

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
        report.name = "new report"
        report.description = "new report description"
        report.price = 52
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        puts "the report errors are --------------->"
        puts report.errors.full_messages.to_s
        assert_equal true, report.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        ## now add another one.
        put diagnostics_report_path(report.id.to_s), params: {report: report.attributes.merge(description: "new report description"), :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers 

        report = Diagnostics::Report.find(report.id.to_s)

        assert_equal "new report description", report.description

    end


    test " -- creates a procedure version for the report, and all the statuses are given id's -- " do 

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
        report.name = "new report"
        report.description = "new report description"
        report.price = 52
        report.created_by_user = @u
        report.created_by_user_id = @u.id.to_s
        report.assign_id_from_name
        report.save
        puts "the report errors are --------------->"
        puts report.errors.full_messages.to_s
        assert_equal true, report.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        ## now add another one.
        put diagnostics_report_path(report.id.to_s), params: {report: report.attributes.merge(description: "new report description"), :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: @headers 

        report = Diagnostics::Report.find(report.id.to_s)

        assert_equal "new report description", report.description        
        assert_equal true, !report.procedure_version.blank?
        
        report.statuses.each do |status|
            assert_equal true, !status.id.to_s.blank?
        end

    end

end