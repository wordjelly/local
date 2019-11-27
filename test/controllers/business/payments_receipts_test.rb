require "test_helper"
require 'helpers/test_helper'
	
class PaymentsReceiptsTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do

        _setup
   	    
    end


    test "plus lab creates a patient, with their own report, and makes a cash payment for him" do 

        o = create_plus_path_lab_patient_order

        puts o.to_s
        puts o.id.to_s

        o = Business::Order.find(o.id.to_s)
       	

        o.receipts[0].payments << Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, status: Business::Payment::APPROVED)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
       	
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        unless response.code.to_s == "204"
            k = JSON.parse(response.body)
            puts k["errors"]
        end
    
        assert_equal "204", response.code.to_s

    end


    test " -- plus lab creates a patient and makes a cheque payment for him -- " do 

		o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
       	
        o.receipts[0].payments << Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CHEQUE, status: Business::Payment::PENDING)


        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
       	
              
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

    
        assert_equal "204", response.code.to_s


    end

    ## this one is running at the moment.
    test " -- plus lab creates a patient and makes a card payment for him -- " do 

		o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
       	
        o.receipts[0].payments << Business::Payment.new(amount: 500, payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CARD, status: Business::Payment::APPROVED)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
              
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

    
        assert_equal "204", response.code.to_s

    end

    test " receipt cannot be added from the user side" do 

        o = create_plus_path_lab_patient_order
        
        o = Business::Order.find(o.id.to_s)
        
        o.receipts << Business::Receipt.new(payable_to_organization_id: "dog", payable_from_organization_id: "cat", payable_from_patient_id: "Rat", force_pdf_generation: true, current_user: User.new, newly_added: true)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
              
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        #puts response.body.to_s
        #puts JSON.pretty_generate(JSON.parse(response.body))
    
    
    end

    test " receipt cannot be deleted " do 
        
        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
        
        o.receipts = []

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

    
        assert_equal "404", response.code.to_s
        #puts response.body.to_s
    
    end

    ## So any changes are thrown out.
    test " cannot change any attribute on receipts other than payments " do 

        o = create_plus_path_lab_patient_order
        
        o = Business::Order.find(o.id.to_s)
        
        o.receipts[0].created_by_user_id = "dog"

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

    
        assert_equal "404", response.code.to_s
        #puts response.body.to_s

    end



    test "cannot change any attribute on a bill type of payment." do 
        
        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)
       
        o.receipts[0].payments.each do |payment|
            puts payment.payment_type
            if payment.is_a_bill?
                puts "payment is a bill and we are changing something in it."
                payment.created_by_user_id = "dog"
            end
        end

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        
        assert_equal "404", response.code.to_s
        #puts response.body.to_s
    
    end

    test " cannot change any attribute on payment other than its status " do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)

        o.receipts[0].add_payment(Business::Payment.new(payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, amount: 400, status: Business::Payment::APPROVED))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)  

        unless order.errors.full_messages.blank?
            puts "error merging the new changes into the order"
            puts order.errors.full_messages
            exit(1)
        end

        o = Business::Order.find(o.id.to_s)

        o.receipts[0].payments[-1].created_by_user_id = "dog"


        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

    
        assert_equal "404", response.code.to_s
        #puts response.body.to_s

    end


    test " can change a payment's status " do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)

        #latika_sawant = User.where(:email => "latika.sawant@gmail.com").first

        #o.created_by_user_id = latika_sawant.id.to_s

        #o.created_by_user = latika_sawant

        #o.run_callbacks(:find)
        
        o.receipts[0].add_payment(Business::Payment.new(payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, amount: 400, status: Business::Payment::APPROVED))

        o = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)  


        #o.save

        unless o.errors.full_messages.blank?
            puts o.errors.full_messages.to_s
            exit(1)
        end

        o = Business::Order.find(o.id.to_s)

        o.receipts[0].payments[-1].status = Business::Payment::APPROVED


        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

    
        assert_equal "204", response.code.to_s
        #puts response.body.to_s

    end



    test " receipt pdf is generated on adding a report " do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)

        receipt_ready_for_pdf_generation = o.receipts[0].ready_for_pdf_generation

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        
        assert_equal "204", response.code.to_s
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        assert_equal receipt_ready_for_pdf_generation, o.receipts[0].ready_for_pdf_generation

    end


    test "receipt pdf is generated on removing a report" do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)

        receipt_ready_for_pdf_generation = o.receipts[0].ready_for_pdf_generation

        puts "template report ids before"
        puts o.template_report_ids.to_s
        o.template_report_ids = o.template_report_ids[0..-2]
        puts "template report ids after"
        puts o.template_report_ids.to_s

        puts "the pdf generated at for the first receip tis:"
        puts receipt_ready_for_pdf_generation.to_s
       # exit(1)

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        
        assert_equal "204", response.code.to_s
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        puts "the pdf generated at of the order later is:"
        puts o.receipts[0].ready_for_pdf_generation.to_s

        assert_not_equal receipt_ready_for_pdf_generation, o.receipts[0].ready_for_pdf_generation

    end


    test " receipt is generated when the user adds a payment. " do 

        o = create_plus_path_lab_patient_order

        o = Business::Order.find(o.id.to_s)

        receipt_ready_for_pdf_generation = o.receipts[0].ready_for_pdf_generation

        o.receipts[0].add_payment(Business::Payment.new(payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, amount: 400, status: Business::Payment::APPROVED))

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        
        assert_equal "204", response.code.to_s
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        assert_not_equal receipt_ready_for_pdf_generation, o.receipts[0].ready_for_pdf_generation


    end


    test "receipt pdf is generated on cancelling a payment" do 


        o = create_plus_path_lab_patient_order

        o = setup_order_for_update(Business::Order.find(o.id.to_s), User.where(:email => "latika.sawant@gmail.com").first)
        
        ## make the required changes.
        o.receipts[0].add_payment(Business::Payment.new(payment_type: Business::Payment::PAYMENT, payment_mode: Business::Payment::CASH, amount: 400, status: Business::Payment::APPROVED))

        order = merge_changes_and_save(Business::Order.find(o.id.to_s),o,User.where(:email => "latika.sawant@gmail.com").first)        

        unless order.errors.full_messages.blank?
            puts "----------- exiting with error ---------"
            puts order.errors.full_messages
            exit(1)
        end

        o = Business::Order.find(o.id.to_s)

        receipt_ready_for_pdf_generation = o.receipts[0].ready_for_pdf_generation

        ## We are cancelling the payment of the payment.
        ## for whatever reason.
        o.receipts[0].payments[-1].status = Business::Payment::CANCELLED

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        
        put business_order_path(o.id.to_s), params: {order: o.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)

        assert_not_equal receipt_ready_for_pdf_generation, o.receipts[0].ready_for_pdf_generation

    end


end