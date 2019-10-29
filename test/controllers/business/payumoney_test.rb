require "test_helper"
require 'helpers/payments_receipts_test_helper'
	

class PayumoneyTest < ActionDispatch::IntegrationTest

    include PaymentsReceiptsTestHelper

    setup do

   		JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          #puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.delete
        User.es.index.create
        Auth::Client.delete_all

        tags = Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        #########################################################
        ##
        ##
        ## CREATING DEVELOPER ACCOUNT AND CLINET.
        ##
        ##
        #########################################################
        #########################################################
        ##
        ##
        ## CREATING DEVELOPER ACCOUNT AND CLINET.
        ##
        ##
        #########################################################
        @u = User.new(email: "developer@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @u.save
        #puts @u.errors.full_messages.to_s
     	#puts @u.authentication_token.to_s
     	#exit(1)
        @u = User.find(@u.id.to_s)
        @u.confirm
        @u.save
        #puts @u.errors.full_messages.to_s
        @u = User.find(@u.id.to_s)
     	#puts @u.authentication_token.to_s
        @c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        @ap_key = @c.api_key
        @u = User.find(@u.id.to_s)

        @u.confirm
        @u.save
        #puts @u.errors.full_messages.to_s
     	#puts @u.authentication_token.to_s
        @c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        @ap_key = @c.api_key

        ## key => user id
        ## value => {auth_token =>  "", client_authentication => ""}
        @security_tokens = {}
        #puts @u.authentication_token.to_s
        #exit(1)
        #########################################################
        ##
        ##
        ## CREATING ALL OTHER USERS.
        ##
        ##
        #########################################################
        Dir.glob(Rails.root.join('test','test_json_models','users','*.json')).each do |user_file_name|
            basename = File.basename(user_file_name,".json")
            user = User.new(JSON.parse(IO.read(user_file_name))["users"][0])
            user.save
            user.confirm
            user.save
            user.client_authentication["testappid"] = BSON::ObjectId.new.to_s
         	user.save
         	@security_tokens[user.id.to_s] = {
         		"authentication_token" => user.authentication_token,
         		"es_token" => user.client_authentication["testappid"]
         	}

            unless user.errors.full_messages.blank?
            	puts "error creating user"
            	exit(1)
            end
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            user = User.find(user.id.to_s)
           		
           	
           	Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
           	
           	## we add it to the organization members,
           	## and thereafter into the organization -> user_ids
           	## that way it will be fine.


            organization = Organization.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','organizations',"#{basename}.json")))["organizations"][0])
            organization.created_by_user = user
            organization.created_by_user_id = user.id.to_s
            organization.who_can_verify_reports = [user.id.to_s]
            organization.role = Organization::LAB
            organization.save 
            unless organization.errors.full_messages.blank?
                puts "errors creating organizaiton--------->"
                puts organization.errors.full_messages.to_s
                exit(1)
            end
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            employee = User.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','employees',"#{basename}.json")))["users"][0])
           	employee.save
           	employee.confirm
           	employee.save
           	employee.client_authentication["testappid"] = BSON::ObjectId.new.to_s
         	employee.save
         	
           	unless employee.errors.full_messages.blank?
           		puts "errors creating employee"
           		exit(1)
           	end
            employee.organization_members << OrganizationMember.new(organization_id: organization.id.to_s, employee_role_id: tags.keys[0])
            employee.save
            unless employee.errors.full_messages.blank?
            	puts "errors saving employee with organization member"
            	exit(1)
            end
            @security_tokens[employee.id.to_s] = {
         		"authentication_token" => employee.authentication_token,
         		"es_token" => employee.client_authentication["testappid"]
         	}
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            organization = Organization.find(organization.id.to_s)
            organization.run_callbacks(:find)
            user = User.find(user.id.to_s)
            organization.created_by_user = user
            organization.created_by_user_id = user.id.to_s
            organization.user_ids << employee.id.to_s
            organization.save
            unless organization.errors.full_messages.blank?
            	puts "errors saving organiztion with user ids -->"
                puts organization.errors.full_messages.to_s
                exit(1)
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            user = User.find(user.id.to_s)
            ## create the credential.
            credential = Credential.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','credentials',"#{basename}.json")))["credentials"][0])
            credential.created_by_user = user
            credential.created_by_user_id = user.id.to_s
            credential.user_id = user.id.to_s
            credential.save 
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            user = User.find(user.id.to_s)
            Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
                report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
                report.created_by_user = user
                report.created_by_user_id = user.id.to_s
                report.save
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

    end

    #cannot_change_any_attribute_on_payment_other_than_its_status
    #can_change_a_payments_status


    test "creating any payment, creates the outgoing hash" do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
       	
        o.receipts[0].payments << Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::ONLINE, status: Business::Payment::PENDING)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
       	
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

      
        assert_equal "204", response.code.to_s

        o = Business::Order.find(o.id.to_s)

        online_payment = o.receipts[0].payments[-1]

        assert_not_nil online_payment.outgoing_hash

    end

    test "Incoming hash is validated if present against the outgoing hash" do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
          
        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        ## make the required changes.
        o.receipts[0].add_payment(Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::ONLINE, status: Business::Payment::PENDING))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)

        ## now we can find the order
        ## and give it an incoming hash.
        o = Business::Order.find(order.id.to_s)
        #puts "the outgoing hash is: #{o.receipts[0].payments[-1].outgoing_hash}"
        #exit(1)
        o.receipts[0].payments[-1].payumoney_payment_status = Concerns::PayUMoneyConcern::PAYUMONEY_PAYMENT_STATUS_SUCCESS
        o.receipts[0].payments[-1].incoming_hash = o.receipts[0].payments[-1].callback_calc_hash
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        assert_equal "204", response.code.to_s

        assert_equal Business::Payment::APPROVED, o.receipts[0].payments[-1].status

    end    


    test " incoming hash mismatch raises an error " do 
        
        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
          
        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        ## make the required changes.
        o.receipts[0].add_payment(Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::ONLINE, status: Business::Payment::PENDING))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)

        ## now we can find the order
        ## and give it an incoming hash.
        o = Business::Order.find(order.id.to_s)
        #puts "the outgoing hash is: #{o.receipts[0].payments[-1].outgoing_hash}"
        #exit(1)
        o.receipts[0].payments[-1].payumoney_payment_status = Concerns::PayUMoneyConcern::PAYUMONEY_PAYMENT_STATUS_SUCCESS
        o.receipts[0].payments[-1].incoming_hash = "anything"
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        assert_equal "404", response.code.to_s

    end

    ##########################################################
    ##
    ##
    ## STATUS CHANGE SPECS
    ##
    ##
    #########################################################=

    test "default status of cash payment must be approved" do 
        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
        
        o.receipts[0].payments << Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, status: Business::Payment::PENDING)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

      
        assert_equal "404", response.code.to_s

    end


    test " status of cash payment can be changed to cancelled " do 
        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
          
        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        ## make the required changes.
        o.receipts[0].add_payment(Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, status: Business::Payment::APPROVED))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)

        ## now we can find the order
        ## and give it an incoming hash.
        o = Business::Order.find(order.id.to_s)
        #puts "the outgoing hash is: #{o.receipts[0].payments[-1].outgoing_hash}"
        #exit(1)
        o.receipts[0].payments[-1].status = Business::Payment::CANCELLED
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

    
    end

    test " status of cash payment cannot be changed to pending " do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
          
        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        ## make the required changes.
        o.receipts[0].add_payment(Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, status: Business::Payment::APPROVED))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)

        ## now we can find the order
        ## and give it an incoming hash.
        o = Business::Order.find(order.id.to_s)
        #puts "the outgoing hash is: #{o.receipts[0].payments[-1].outgoing_hash}"
        #exit(1)
        o.receipts[0].payments[-1].status = Business::Payment::PENDING
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

    
    end

    test " online payment status first being internally set to approved, cannot be later changed to pending/cancelled. " do 

        o = create_plus_path_lab_patient_order

          
        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        ## make the required changes.
        o.receipts[0].add_payment(Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::ONLINE, status: Business::Payment::PENDING))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)
        #######################################################
        ##
        ##
        ## 
        ##
        ##
        #######################################################
        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        o.receipts[0].payments[-1].payumoney_payment_status = Concerns::PayUMoneyConcern::PAYUMONEY_PAYMENT_STATUS_SUCCESS
        ## make the required changes.
        o.receipts[0].payments[-1].incoming_hash = o.receipts[0].payments[-1].callback_calc_hash

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)
        #######################################################
        ##
        ##
        ##
        ##
        #######################################################
       
        o = Business::Order.find(order.id.to_s)
        #puts "the outgoing hash is: #{o.receipts[0].payments[-1].outgoing_hash}"
        #exit(1)
        o.receipts[0].payments[-1].status = Business::Payment::CANCELLED
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        assert_equal "404", response.code.to_s

        #assert_equal Business::Payment::APPROVED, o.receipts[0].payments[-1].status
    end


    
end