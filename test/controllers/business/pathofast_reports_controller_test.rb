require "test_helper"
require 'helpers/test_helper'
class PathofastReportsControllerTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do


   		_setup(
   			{
   				"bhargav_raut" => 
   				{
   					"reports_folder_path" => (Rails.root.join('vendor','assets','processed_report_formats','T3.json'))
   				}
   			}
   		)
		
		@security_tokens = JSON.parse($redis.get("security_tokens"))
   		@ap_key = $redis.get("ap_key")

    end

=begin
    test " - loads all immunoassay reports into an order - " do 

    	order = build_pathofast_patient_order(nil,nil)

        pathofast_employee = User.where(:email => "priya.hajare@gmail.com").first

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,pathofast_employee)


        assert_equal "201", response.code.to_s

    end
=end
	
=begin
    test "upper age limit of range is inclusive, and lower limit is exclusive" do 
    	
    	## so a patient with 6 days will be interpreted where.
    	## and a patient with six days and 1 hour will be interpreted where
    	## this has to be cleared.
    	## when you say the next range starts at 6 days which one is implied?
    	patient = create_patient_of_age({
    		"years" => 0,
    		"months" => 0,
    		"days" => 6,
    		"hours" => 0,
    		"created_by_user" => User.where(:email => "priya.hajare@gmail.com").first
    	})
    	

    	order = create_pathofast_patient_order(nil,patient)

        pathofast_employee = User.where(:email => "priya.hajare@gmail.com").first

        order = Business::Order.find(order.id.to_s)

        ## add the values
        ## of the creatinine.
        ## now we want to add a result to 
        #order.reports[0].tests[0].result_raw = 15
        t3_report_index = 0
        order.reports.select.with_index{|val,index|
        	if (val.name == "Tri-iodothyronine(T3)")
        		t3_report_index = index
        	end
        }

        order.reports[t3_report_index].tests[0].result_raw = 2.1

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,pathofast_employee)

        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)

        picked_range = order.reports[t3_report_index].tests[0].ranges.select{|c|
            c.picked == Diagnostics::Range::YES
        }

        assert_equal 1, picked_range.size
        
        range = picked_range[0]
        puts "the picked range is:"
        puts JSON.generate(range.attributes)
        assert_equal 6, range.max_age_days


    end

    test " lower limit of val is inclusive, and upper limit is exclusive " do 

    	patient = create_patient_of_age({
    		"years" => 0,
    		"months" => 0,
    		"days" => 6,
    		"hours" => 0,
    		"created_by_user" => User.where(:email => "priya.hajare@gmail.com").first
    	})
    	
    	order = create_pathofast_patient_order(nil,patient)

        pathofast_employee = User.where(:email => "priya.hajare@gmail.com").first

        order = Business::Order.find(order.id.to_s)

        ## add the values
        ## of the creatinine.
        ## now we want to add a result to 
        #order.reports[0].tests[0].result_raw = 15
        t3_report_index = 0
        order.reports.select.with_index{|val,index|
        	if (val.name == "Tri-iodothyronine(T3)")
        		t3_report_index = index
        	end
        }

        order.reports[t3_report_index].tests[0].result_raw = 2.88

        put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,pathofast_employee)

        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        order = Business::Order.find(order.id.to_s)

        picked_range = order.reports[t3_report_index].tests[0].ranges.select{|c|
            c.picked == Diagnostics::Range::YES
        }

        assert_equal 1, picked_range.size
        
        range = picked_range[0]
        puts "the picked range is:"
        puts JSON.generate(range.attributes)
        assert_equal 6, range.max_age_days


        tag = range.get_picked_tag
        assert_equal true, !tag.blank?
        assert_equal tag.min_range_val, 2.88
		

    end
=end

=begin
	test " no range has been specified for this age and sex, also prints all the remaining ranges" do 


	end

	test " history tags not provided -> all ranges are printed, no interpretation is attempted -- " do 

	end

	## eg transferrin saturation.
	## so this report should be autopopulated with a value, if it is not already populated.
	## by means of an inherent formula
	## same for vldl, bun, etc.
	## anion gaps whatever else.
	test " calculated parameters are generated on having enough values for the basic reports " do 

	end
=end

    test " thyroid uses trimester specific value " do 
    	
    end



end