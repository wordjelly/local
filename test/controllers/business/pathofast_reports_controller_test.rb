require "test_helper"
require 'helpers/test_helper'
class PathofastReportsControllerTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do
   		_setup(
   			{
   				"bhargav_raut" => 
   				{
   					"reports_folder_path" => (Rails.root.join('vendor','assets','pathofast_report_formats','immunoassay','*.json'))
   				}
   			}
   		)
    end

    test " - loads T4 report into order - " do 

=begin
    	order = build_plus_path_lab_patient_order

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        post business_orders_path, params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)
=end
    end

end