require "test_helper"
require 'helpers/test_helper'
class OrderAccessibilityTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do

   		_setup

    end

=begin
    ## should this have the sign ?
    test "consent to perform test" do 
    
        ## how does this work?
        ## whoever creates the order -> gives the consent.
        ## 

    end
    #####################################


    test "patient can create order, does not need to add tubes, can finalize" do 

    end

    test "doctor can create order, delegate to organization, does not need to finalize" do 


    end


    test "order can override organization level settings for reports, billing etc" do 

    end


    test " patient on signing up, gets his own organization automatically " do 


    end

    test " organization on being created gets a patient " do 

    end

    test " plus path lab creates an order, outsources a report to pathofast , plus cannot edit the values in that report" do 

    end

    test " plus path lab creates an order, outsources a report to pathofast, pathofast users can edit the value in that report " do 

    end

    test " user on creation -> can create a patient organization and can create an order based on that " do 

    end

    test " plus path lab creates an order with one internal and one outsourced report, they can make an online payment for the pathofast report "

   	end

   	test " plus path lab creates an order with one internal and one outsourced report, they cannot create a cash/card/cheque payment for the pathofast report."

   	end

   	test " order has setting to override global billing setting " do 

   	end

   	test " pathofast cannot edit values in plus paths report in the shared order " do 

   	end

   	test " doctor can upload picture and delegate the entire order to one organization, who can add reports, like usual " do 

   	end

   	test " patient can access the report pdf url " do 

   	end
    ########################################################
    ##
    ##
    ## AVAILABILITY API ---> hooks into the status api.
    ## 
    ##
    ##
    ########################################################
    ## TODO 15th
    test " order returns nearest available slots to desired time, for requested reports " do 

    end

    #######################################################
    ##
    ##
    ## ORDER TAGS
    ##
    ##
    #######################################################
    test " order has option for home visit -> tags on the order " do 


    end

    test " order has option for techinician visit to doctor -> tags on the order" do 

    end

    
    test " order has option for delivery boy visit to doctor/another lab " do 

    end
    
    #######################################################
    test " organization can define daily preferred round time " do 


    end

    test " organization on giving its location shows the transport options " do 

    end

    test " terms and conditions automatically established on organization sign up " do 


    end

    test "organization can request inventory from another organization, and this gets approved depending on how many tests they have consumed or sent" do 


    end
    ## how to monitor organization inventory, and request for more tubes, and how does that work out exactly ?
    ## i want all that handled by software as well.
    ########################################################
    ##
    ##
    ## NOTIFICATION TO PATIENTS/DOCTORS -> QUEUED BY TIME.
    ##
    ##
    ########################################################
    test " each test can have information to be sent to (patient), (doctor), lab at a certain time before or after the test" do 


    end
    
    test " the information can include a url / video link " do 
    end

    test " patient review/ doctor review / on the order can be accepted " do 

    end

    test " review can be specific to certain statuses, and cannot be edited by the lab staff " do 


    end

    test " patient gets the google review notification after the order is completed " do 


    end

    test " alert value notifications are sent to the doctor " do 

    end

    test " user can see pending worklist " do 


    end

    test " user can see entire schedule " do 


    end
    ########################################################
    ##
    ##
    ## SENDING THE REPORTS/ maybe this comes in the notifications
    ## 
    ########################################################,
=end
=begin
    test " order is populated with the patient and creating user of the order, as well as the organizations default recipients as default recipients " do 
        
        order = build_plus_path_lab_patient_order

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        #puts response.body.to_s
        order = Business::Order.new(JSON.parse(response.body)["order"])

        #puts "the order id is: #{order.id.to_s}"

        assert_equal "201", response.code.to_s   

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Business::Order.find(order.id.to_s)

        #puts "THESE ARE THE EXISTING RECIPIENTS IN THE ORDER ------------------------>

        assert_equal 3, o.recipients.size

    end


    test " orders can accept additional recipients " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        order = create_plus_path_lab_patient_order([reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        additional_recipient = Notification::Recipient.new(phone_numbers: ["9822028511"])

        order.additional_recipients << additional_recipient

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        o = Business::Order.find(order.id.to_s)

        ## so if a different user updates the order -> then it goes to all of them.

        assert_equal 4, o.recipients.size

        assert_equal 1, o.additional_recipients.size

    end
=end

=begin
    test " can resend the report by means of an attr_accessor, to some parties, for eg mark some parties to resend the report to setting " do 

        ## okay so how does this work.

    end

    test " can disable a certain additional recipient from being sent the notification " do 
            

    end
=end

    test " pdf generated for receipt and reports if all reports get verified " do 
        
        ActionMailer::Base.deliveries = []

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        order = create_plus_path_lab_patient_order([reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        puts ActionMailer::Base.deliveries.to_s

        exit(1)

        ## here the ready_to_generate_pdf should be nil
        assert_nil order.ready_for_pdf_generation
        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15
        ## verify the damn report.
        order.reports[0].tests[0].verification_done = 1

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        order = Business::Order.find(order.id.to_s)

        assert_equal true, order.ready_for_pdf_generation.blank?

        puts "the order pdf url is: #{order.pdf_url}"

        assert_equal 1, order.receipts.size
        order.receipts.each do |receipt|
            actual_receipt = Business::Receipt.find(receipt.id.to_s)
            puts "receipt pdf url is: #{actual_receipt.pdf_url}"
            assert_same true, !actual_receipt.pdf_url.blank?
        end
        ## how to check if notifications were sent
        ## we just write to a database
        ## 
        assert_same true, !order.pdf_url.blank?

        ## check if emails were sent
        ## how many emails should have been sent ?
        ## one for the receipt
        ## one for the order
        ##mail = ActionMailer::Base.deliveries.last
        assert_equal 2, ActionMailer::Base.deliveries.size, "2 email notifications were sent"
    end

=begin
    test " pdf not generated if no reports are verified " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        order = create_plus_path_lab_patient_order([reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        ## here the ready_to_generate_pdf should be nil
        assert_nil order.ready_for_pdf_generation
        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15
        ## verify the damn report.
        ## order.reports[0].tests[0].verification_done = 1

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        order = Business::Order.find(order.id.to_s)

        assert_equal true, order.ready_for_pdf_generation.blank?

    end

    test " pdf generated if only one report is verified and partial order reports are enabled " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        creat_reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})
        puts "creat reports are:"
        puts creat_reports.to_s

        urea_reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "urea"})
        puts "urea reports are:"
        puts urea_reports.to_s

        order = create_plus_path_lab_patient_order([creat_reports[0].id.to_s,urea_reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        ## here the ready_to_generate_pdf should be nil
        assert_nil order.ready_for_pdf_generation
        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15
        ## verify the damn report.
        order.reports[0].tests[0].verification_done = 1

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        order = Business::Order.find(order.id.to_s)

        assert_equal false, order.ready_for_pdf_generation.blank?

    end

    test " pdf not generated if force pdf generation is false, and at least one report is verified, but not in the present request " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        creat_reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})
        #puts "creat reports are:"
        #puts creat_reports.to_s

        urea_reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "urea"})
        #puts "urea reports are:"
        #puts urea_reports.to_s

        order = create_plus_path_lab_patient_order([creat_reports[0].id.to_s,urea_reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        ## here the ready_to_generate_pdf should be nil
        assert_nil order.ready_for_pdf_generation
        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15
        ## verify the damn report.
        order.reports[0].tests[0].verification_done = 1

        order = merge_changes_and_save(Business::Order.find(order.id.to_s),order,plus_lab_employee)  

        order = Business::Order.find(order.id.to_s)

        pdf_generation_time = order.ready_for_pdf_generation

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        order = Business::Order.find(order.id.to_s)

        assert_nil order.ready_for_pdf_generation

    end


    test " pdf generated if force pdf generation is true, and at least one report is verified, but not in the present request " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        creat_reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})
        puts "creat reports are:"
        puts creat_reports.to_s

        urea_reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "urea"})
        puts "urea reports are:"
        puts urea_reports.to_s

        order = create_plus_path_lab_patient_order([creat_reports[0].id.to_s,urea_reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        ## here the ready_to_generate_pdf should be nil
        assert_nil order.ready_for_pdf_generation
        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15
        ## verify the damn report.
        order.reports[0].tests[0].verification_done = 1

        order = merge_changes_and_save(Business::Order.find(order.id.to_s),order,plus_lab_employee)  

        order = Business::Order.find(order.id.to_s)

        pdf_generation_time = order.ready_for_pdf_generation

        #order.force_pdf_generation = true

        put business_order_path(order.id.to_s), params: {order: order.attributes.merge({:force_pdf_generation => true}), :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        order = Business::Order.find(order.id.to_s)

        assert_not_equal pdf_generation_time, order.ready_for_pdf_generation


    end
=end

end