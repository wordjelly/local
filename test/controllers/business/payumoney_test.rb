require "test_helper"
require 'helpers/test_helper'
	

class PayumoneyTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do
        _setup
    end


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