require "test_helper"
require 'helpers/test_helper'
class PathofastReportsControllerTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do

=begin
   		_setup(
   			{
   				"bhargav_raut" => 
   				{
   					"reports_folder_path" => (Rails.root.join('vendor','assets','pathofast_report_formats','immunoassay','*.json'))
   				}
   			}
   		)
   		
		#Business::Order.create_index! force: true
=end    	
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
	
    test "upper age limit of range is inclusive" do 
    	
    	

    	patient = create_patient_of_age({
    		"years" => 0,
    		"months" => 0,
    		"days" => 4,
    		"hours" => 0,
    		"created_by_user" => User.where(:email => "priya.hajare@gmail.com").first
    	})
    	

    	order = build_pathofast_patient_order(nil,patient)

        pathofast_employee = User.where(:email => "priya.hajare@gmail.com").first

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,pathofast_employee)

        ## okay so if we want to only create the pathofast orders its
        ## okay.
        ## and which reports to create.

        assert_equal "201", response.code.to_s

    end

=begin
    test "lower limit of age is exclusive" do 

    end

    test "define value range as greater than, so don't display the upper limit" do 

    end

    test "define value range as less than, so don't display the upper limit" do 

    end
=end


end