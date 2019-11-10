require "test_helper"
require "helpers/test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest

    include TestHelper
    
    setup do

        _setup

    end

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

    test " -- on adding an item, updates to all relevant reports, and reduces required quantities of all other categories --" do 

        

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


    test " - creatinine value is normal, so picks the normal range from the tags - " do 
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        creatinine_report = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        #puts "the creatinine report we found is:"
        #puts creatinine_report.to_s
        #exit(1)

        order = create_plus_path_lab_patient_order([creatinine_report.id.to_s])

        order = Business::Order.find(order.id.to_s)

        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15


        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        order = Business::Order.new(JSON.parse(response.body)["order"])

        #assert_equal true, !order.categories.blank?
           


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

    test " - calculates the weeks of gestation based on the LMP - " do 

    end

    test " - no range satisfies the value - " do 

    end

    test " - more than one history range satisfies the value - " do 
        
    end

    test " - more than one combination history range satisfies the value - " do 


    end

=end





end