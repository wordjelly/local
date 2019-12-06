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
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

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

    test " - picks the range as per the history answer(Textual) - " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee)

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

    ## okay can do this quick.    
    test " - picks the range as per the history answer(numeric) - " do 
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]

        required_number_history_tag = create_required_number_history_tag(plus_lab_employee)

        creat_report.tests[0].template_tag_ids << required_number_history_tag.id.to_s
        
        creat_report.tests[0].ranges[0].template_tag_ids << required_number_history_tag.id.to_s

        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 

        creat_report = Diagnostics::Report.find(creat_report.id.to_s)

        ## we want to give it a textual history val.
        ## so it can be something like how many days since you last smoked.
        creat_report.tests[0].ranges[0].tags[-1].min_history_val = 4
        creat_report.tests[0].ranges[0].tags[-1].max_history_val = 14
        
        
        ## so its just a tag added to an existing age range.
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee)

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
        order.reports[0].tests[0].tags[0].numerical_history_response = 6


        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)


        assert_equal "204", response.code.to_s

        o = Business::Order.find(order.id.to_s)

        assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked


    end

   

    test " - if multiple tests require an answer to the same tag, then it ignores errors if any one test has answered that question - " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "hemogram"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        hemogram_report = reports[0]
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
        hemogram_report.tests[0].template_tag_ids << required_history_tag.id.to_s
        hemogram_report.tests[0].ranges[0].template_tag_ids << required_history_tag.id.to_s

        hemogram_report.tests[1].template_tag_ids << required_history_tag.id.to_s
        hemogram_report.tests[1].ranges[0].template_tag_ids << required_history_tag.id.to_s

        hemogram_report = merge_changes_and_save(Diagnostics::Report.find(hemogram_report.id.to_s),hemogram_report,plus_lab_employee)  

        unless hemogram_report.errors.full_messages.blank?
            puts "error hemograming merged report"
            exit(1)
        end 

        hemogram_report = Diagnostics::Report.find(hemogram_report.id.to_s)

        ## we want to give it a textual history val.
        hemogram_report.tests[0].ranges[0].tags[-1].text_history_val = Tag::YES.to_s
        ## i think here, the min and max range vals don't 
        ## need to be checked


        hemogram_report = merge_changes_and_save(Diagnostics::Report.find(hemogram_report.id.to_s),hemogram_report,plus_lab_employee)  

        unless hemogram_report.errors.full_messages.blank?
            puts "error hemograming merged report"
            exit(1)
        end 
        ################################################
        ##
        ##
        ## CREATE AND FINALIZE ORDER.
        ##
        ##
        ###############################################

        order = create_order_and_add_tube(hemogram_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee,0,12)

        order = Business::Order.find(order.id.to_s)

        order = add_value_to_order(order,plus_lab_employee,1,15)        

        #############################################
        ##
        ##
        ## 
        ##
        ##
        #############################################
        ## answer the question in the first test
        ## dont answer it in the second test, as it is the same tag.
        order.reports[0].tests[0].tags[0].text_history_response = Tag::YES.to_s


        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)


        #k = JSON.parse(response.body)
        #puts k["errors"]

        assert_equal "204", response.code.to_s


        #o = Business::Order.find(order.id.to_s)

        #assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked

    end

    test " - if multiple histories are there, picks the combined range -- " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]

        ## i cannot believe i gave myself one more day for this.
        ## but today we can deliver.
        ## ADD NUMBER TAG.
        required_number_history_tag = create_required_number_history_tag(plus_lab_employee)

        creat_report.tests[0].template_tag_ids << required_number_history_tag.id.to_s
        
        creat_report.tests[0].ranges[0].template_tag_ids << required_number_history_tag.id.to_s


        ## ADD TEXT TAG
        required_text_history_tag = 
            create_required_text_history_tag(plus_lab_employee)

        creat_report.tests[0].template_tag_ids << required_text_history_tag.id.to_s
        
        creat_report.tests[0].ranges[0].template_tag_ids << required_text_history_tag.id.to_s

        ## add this twice as the second one is going to be in combination.
        creat_report.tests[0].ranges[0].template_tag_ids << required_text_history_tag.id.to_s




        ## i want to add this in combination also.
        ## into the range -> using the combination id.
        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 

        creat_report = Diagnostics::Report.find(creat_report.id.to_s)

        ## we want to give it a textual history val.
        ## so it can be something like how many days since you last smoked.
        ## so this tag is -2
        ## the combination tag is the numeric + the nested tag id of the text tag.
        creat_report.tests[0].ranges[0].tags[-1].text_history_val = Tag::YES
        creat_report.tests[0].ranges[0].tags[-1].combined_with_history_tag_ids = creat_report.tests[0].ranges[0].tags[-3].nested_id
        creat_report.tests[0].ranges[0].tags[-2].text_history_val = Tag::YES
        creat_report.tests[0].ranges[0].tags[-3].min_history_val = 4
        creat_report.tests[0].ranges[0].tags[-3].max_history_val = 14
        ## add one more tag the numerical in combination.
        


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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee)

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
        order.reports[0].tests[0].tags[0].numerical_history_response = 6

        order.reports[0].tests[0].tags[1].text_history_response = Tag::YES.to_s

        ## so it should not be complaining about this actually.

        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        unless response.code.to_s == "204"
            k = JSON.parse(response.body)
            puts k["errors"].to_s
        end

        assert_equal "204", response.code.to_s

        o = Business::Order.find(order.id.to_s)

        assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked

    end

    test " - calculates time since given date - " do 
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee)

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
        order.reports[0].tests[0].ranges[0].tags[-1]._date = (DateTime.now - 10.days)
        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

         Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Business::Order.find(order.id.to_s)

        assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked
        assert_not_nil o.reports[0].tests[0].ranges[0].tags[-1].completed_years_since_date
        assert_not_nil o.reports[0].tests[0].ranges[0].tags[-1].completed_months_since_date
        assert_not_nil o.reports[0].tests[0].ranges[0].tags[-1].completed_weeks_since_date
        assert_not_nil o.reports[0].tests[0].ranges[0].tags[-1].completed_days_since_date

    end 

    ## so order accssibility -> should this come first ?
    ## i think so.
    ## because that is the main stickler.
    ## then payu and others.

    test " - no history range satisfies the provided history answer, should fallback on the normal ranges - " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee)

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
        order.reports[0].tests[0].tags[-1].text_history_response = "allah-o-akbar"
       
        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

         Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Business::Order.find(order.id.to_s)

        ## the last tag should not get picked.
        ## we basically will just print the normal range.
        ## 
        assert_equal nil, creat_report.tests[0].ranges[0].tags[-1].picked

    end

    test " -- value is abnormal, picks the abnormal range - " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee,0,22)

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
        order.reports[0].tests[0].tags[-1].text_history_response = "allah-o-akbar"
       
        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Business::Order.find(order.id.to_s)

        
        assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[1].picked
        assert_equal nil, o.reports[0].tests[0].ranges[0].tags[0].picked

    end 


    test " - value is abnormal but no abnormal range satsifies it - " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]
        required_history_tag = create_required_text_history_tag(plus_lab_employee)
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

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee,0,500)

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
        order.reports[0].tests[0].tags[-1].text_history_response = "allah-o-akbar"
       
        order.finalize_order = Business::Order::YES

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204", response.code.to_s

         Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Business::Order.find(order.id.to_s)

        ## the last tag should not get picked.
        ## we basically will just print the normal range.
        ## 
        #assert_equal nil, creat_report.tests[0].ranges[0].tags[1].picked
        assert_equal nil, o.reports[0].tests[0].ranges[0].tags[0].picked
        assert_equal nil, o.reports[0].tests[0].ranges[0].tags[1].picked
        assert_equal nil, o.reports[0].tests[0].ranges[0].tags[2].picked

    end

    test " - more than one history range satisfies the value, should raise an error - " do 
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        reports = Diagnostics::Report.find_reports({:organization_id => plus_lab_employee.organization_members[0].organization_id, :report_name => "creatinine"})

        ## ADD THE REQUIRED HISTORY TAG TO THE CREATININE REPORT
        creat_report = reports[0]

        required_number_history_tag = create_required_number_history_tag(plus_lab_employee)

        required_text_history_tag = create_required_text_history_tag(plus_lab_employee)

        creat_report.tests[0].template_tag_ids << required_text_history_tag.id.to_s
        
        creat_report.tests[0].ranges[0].template_tag_ids << required_text_history_tag.id.to_s

        creat_report.tests[0].template_tag_ids << required_number_history_tag.id.to_s
        
        creat_report.tests[0].ranges[0].template_tag_ids << required_number_history_tag.id.to_s

        


        ## so lets say a required number and text history tag satisfy it seperately.

        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 

        creat_report = Diagnostics::Report.find(creat_report.id.to_s)

        ## we want to give it a textual history val.
        ## so it can be something like how many days since you last smoked.

        creat_report.tests[0].ranges[0].tags[-1].min_history_val = 4
        creat_report.tests[0].ranges[0].tags[-1].max_history_val = 14
        creat_report.tests[0].ranges[0].tags[-2].text_history_val = Tag::YES
        

        ## i think here, the min and max range vals don't 
        ## need to be checked
        creat_report = merge_changes_and_save(Diagnostics::Report.find(creat_report.id.to_s),creat_report,plus_lab_employee)  

        unless creat_report.errors.full_messages.blank?
            puts "error creating merged report"
            exit(1)
        end 


        creat_report = Diagnostics::Report.find(creat_report.id.to_s)
        puts "the creat report DIRECT tags are:"
        puts creat_report.tests[0].tags.to_s
       # exit(1)
        ################################################
        ##
        ##
        ## CREATE AND FINALIZE ORDER.
        ##
        ##
        ###############################################

        order = create_order_and_add_tube(creat_report,plus_lab_employee)

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)
        
        order = add_value_to_order(order,plus_lab_employee)

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
        order.reports[0].tests[0].tags[1].numerical_history_response = 6
        order.reports[0].tests[0].tags[0].text_history_response = Tag::YES


        order.finalize_order = Business::Order::YES

        puts " ----------------------- CHECK THIS CALL ---------------------- "
        
        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)


        assert_equal "404", response.code.to_s

        # okay so multi match is failing.
        # o = Business::Order.find(order.id.to_s)

        # assert_equal Tag::YES, o.reports[0].tests[0].ranges[0].tags[-1].picked

    end
=end
    

 





end