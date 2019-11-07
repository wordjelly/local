require "test_helper"
require 'helpers/test_helper'
	

class ReportsControllerRangesTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do

        _setup

    end

    test " error if no range accounts for an age category, while  adding a test " do 
            
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("age_range_missing")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        puts k.to_s
        assert_not_nil (k["errors"] =~ /Ranges contiguous ranges absent/)

    end

    test " error if no range accounts for a particular gender, while adding a test " do
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("gender_range_missing")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        puts k.to_s
        assert_not_nil (k["errors"] =~ /first range for either male or female does not start at 0 years/)
    end

    test " error if range overlaps for a particular gender " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("range_overlap")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        #puts k.to_s
        assert_not_nil (k["errors"] =~ /Ranges contiguous ranges absent/)

    end

    test " abnormal and normal ranges for the same age/gender criteria don't cause the overlap error " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_valid_report("creatinine")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "201", response.code.to_s

    end

    test " abnormal and normal ranges cannot overlap in min max value range" do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("abnormal_normal_value_overlap")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        puts k.to_s
        assert_not_nil (k["errors"] =~ /#{I18n.t("min_max_overlap_error")}/)
    end

    test "does not raise error for male range, if the test is only applicable to males" do 
        
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_valid_report("xyz")
        

        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "201", response.code.to_s

    end

    test "does not allow to add a male range AND female range if the range is only applicable to females" do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("male_and_female_range_specified_for_female_test")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        puts k.to_s
        puts k["errors"]
        assert_not_nil (k["errors"] =~ /the first range for either/)

    end


    test "does not allow to add a male range if the range is only applicable to females" do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("male_range_provided_for_female_test")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        puts k.to_s
        assert_not_nil (k["errors"] =~ /selected gender/)

    end

    ## next will be history , range interpretation tests.

    test " inference must be defined for abnormal ranges " do 
         plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("inference_not_defined")
        
        post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "404", response.code.to_s
        k = JSON.parse(response.body)
        assert_not_nil (k["errors"] =~ /Inference can\'t be blank/i)
        #puts k.to_s
    end

  
end
