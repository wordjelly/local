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

    test " - creatinine value is normal, so picks the normal range from the tags - " do 
        
        

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        #puts "the creatinine report we found is:"
        #puts creatinine_report.to_s
        #exit(1)

        order = create_plus_path_lab_patient_order([reports[0].id.to_s])

        order = Business::Order.find(order.id.to_s)

        ## add the values
        ## of the creatinine.
        order.reports[0].tests[0].result_raw = 15

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)

        picked_range = order.reports[0].tests[0].ranges.select{|c|
            c.picked == Diagnostics::Range::YES
        }

        assert_equal 1, picked_range.size
        
        range = picked_range[0]

        if tag = range.get_picked_tag
            assert_equal 10, tag.min_range_val
            assert_equal 20, tag.max_range_val
        else
            assert_equal true,false
        end        

    end


    test " - if a test has a required history question, then does not go forward till that is answered -- " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_history_tag(plus_lab_employee)
        creat_report.tests[0].template_tag_ids << required_history_tag.id.to_s


        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        #puts creat_report.tests[0].tags.to_s
        #exit(1)

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 

        ################################################
        ##
        ##
        ## CREATE AND FINALIZE ORDER.
        ##
        ##
        ###############################################

        order = create_creatinine_order_and_add_tube(creat_report,plus_lab_employee)

        #############################################
        ##
        ##
        ## 
        ##
        ##
        #############################################
        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s

        k = JSON.parse(response.body)

        puts k["errors"]

    end
=end

=begin
    test " - picks the range as per the history answer(Textual) - " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_history_tag(plus_lab_employee)
        creat_report.tests[0].template_tag_ids << required_history_tag.id.to_s
        creat_report.tests[0].ranges[0].template_tag_ids << required_history_tag.id.to_s

        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 

        creat_report = Diagnostics::Report.find(creat_report.id.to_s)

        ## we want to give it a textual history val.
        creat_report.tests[0].ranges[0].tags[-1].text_history_val = Tag::YES.to_s
        ## i think here, the min and max range vals don't 
        ## need to be checked


        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 
        ################################################
        ##
        ##
        ## CREATE AND FINALIZE ORDER.
        ##
        ##
        ###############################################

        order = create_creatinine_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_normal_value_to_creatinine_order(order,plus_lab_employee)

        #############################################
        ##
        ##
        ## 
        ##
        ##
        #############################################
        ## answer the question in the first test
        ## so the range interpretation will happen anwwyas.
        ## so when the value is added to the test
        order.reports[0].tests[0].tags[0].text_history_response = Tag::YES.to_s


        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)


        assert_equal "204", response.code.to_s

        o = Business::Order.find(order.id.to_s)

        assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked

    end
=end
    
    ## okay can do this quick.    
    test " - picks the range as per the history answer(numeric) - " do 
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_history_tag(plus_lab_employee)
        creat_report.tests[0].template_tag_ids << required_history_tag.id.to_s
        creat_report.tests[0].ranges[0].template_tag_ids << required_history_tag.id.to_s

        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 

        creat_report = Diagnostics::Report.find(creat_report.id.to_s)

        ## we want to give it a textual history val.
        creat_report.tests[0].ranges[0].tags[-1].text_history_val = Tag::YES.to_s
        ## i think here, the min and max range vals don't 
        ## need to be checked


        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 
        ################################################
        ##
        ##
        ## CREATE AND FINALIZE ORDER.
        ##
        ##
        ###############################################

        order = create_creatinine_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_normal_value_to_creatinine_order(order,plus_lab_employee)

        #############################################
        ##
        ##
        ## 
        ##
        ##
        #############################################
        ## answer the question in the first test
        ## so the range interpretation will happen anwwyas.
        ## so when the value is added to the test
        order.reports[0].tests[0].tags[0].text_history_response = Tag::YES.to_s


        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)


        assert_equal "204", response.code.to_s

        o = Business::Order.find(order.id.to_s)

        assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked


    end

=begin
    test " - cannot edit the history question inside the test, only the answers - " do 

    end

    test " - if multiple tests require an answer to the same tag, then it ignores errors if any one test has answered that question - " do 

    end

    test " - if multiple histories are there, picks the combined range -- " do 

    end

    test " - calculates the weeks of gestation based on the LMP - " do 

    end

    test " - no history range satisfies the value provided - " do 

    end

    test " - no abnormal range satisfies the value provided - " do 

    end
    

    test " - more than one history range satisfies the value - " do 
        
    end

    test " - more than one combination history range satisfies the value - " do 

    end

    # that still comes to about 4.5 hours.
    # excercise today has to be about 

=end





end