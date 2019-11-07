require "test_helper"
require 'helpers/test_helper'
	
class ReportsHistoryRangeTest < ActionDispatch::IntegrationTest

    include TestHelper

    setup do

   		_setup

    end

    ## let me get a common helper working
    ## and then some more stuff
    ## so that this is all more streamlined.

    test " adds a history tag to a range inside a test " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        t = Tag.new
        t.description = "Is the Patient a smoker"
        t.tag_type = Tag::HISTORY_TAG
        t.history_options = [Tag::YES.to_s,Tag::NO.to_s]
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        t.created_by_user = plus_lab_employee
        t.created_by_user_id = plus_lab_employee.id.to_s
        t.save
        unless t.errors.full_messages.blank?
            puts "errors #{t.errors.full_messages} while creating tag"
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
            report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
            report.created_by_user = plus_lab_employee
            report.created_by_user_id = plus_lab_employee.id.to_s
            report.tests[0].ranges[0].template_tag_ids << t.id.to_s
            post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)
            assert_equal "201", response.code.to_s
            
            k = JSON.parse(response.body)

            r = Diagnostics::Report.new(k["report"])

            assert_equal r.tests[0].ranges[0].tags.size , 3

            break
        end

    end

    test " removes a history tag from a range inside a test " do 
    
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        t = Tag.new
        t.description = "Is the Patient a smoker"
        t.tag_type = Tag::HISTORY_TAG
        t.range_type = Tag::HISTORY_TAG
        t.history_options = [Tag::YES.to_s,Tag::NO.to_s]
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        t.created_by_user = plus_lab_employee
        t.created_by_user_id = plus_lab_employee.id.to_s
        t.save

        unless t.errors.full_messages.blank?
            puts "errors #{t.errors.full_messages} while creating tag"
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        report_id = nil

        Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
            report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
            report.created_by_user = plus_lab_employee
            report.created_by_user_id = plus_lab_employee.id.to_s
            report.tests[0].ranges[0].template_tag_ids << t.id.to_s
            report.save
            report_id = report.id.to_s
            assert_equal true, report.errors.full_messages.blank?
            break
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        r = Diagnostics::Report.find(report_id)
        #puts r.tests[0].ranges[0].tags.to_s
        #exit(1)
        
        r.tests[0].ranges[0].template_tag_ids = []

        put diagnostics_report_path(r.id.to_s), params: {report: r.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204",response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        r = Diagnostics::Report.find(r.id.to_s)

        assert_equal 2, r.tests[0].ranges[0].tags.size

    end


    test " adds a history tag to a test " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        t = Tag.new
        t.description = "Is the Patient a smoker"
        t.tag_type = Tag::HISTORY_TAG
        t.history_options = [Tag::YES.to_s,Tag::NO.to_s]
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        t.created_by_user = plus_lab_employee
        t.created_by_user_id = plus_lab_employee.id.to_s
        t.save
        unless t.errors.full_messages.blank?
            puts "errors #{t.errors.full_messages} while creating tag"
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
            report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
            report.created_by_user = plus_lab_employee
            report.created_by_user_id = plus_lab_employee.id.to_s
            report.tests[0].template_tag_ids << t.id.to_s
            post diagnostics_reports_path, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)
            assert_equal "201", response.code.to_s
            
            k = JSON.parse(response.body)

            r = Diagnostics::Report.new(k["report"])

            assert_equal 1,r.tests[0].tags.size

            break
        end

    end


    test " removes a history tag from a test  " do 

        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        t = Tag.new
        t.description = "Is the Patient a smoker"
        t.tag_type = Tag::HISTORY_TAG
        t.range_type = Tag::HISTORY_TAG
        t.history_options = [Tag::YES.to_s,Tag::NO.to_s]
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
        t.created_by_user = plus_lab_employee
        t.created_by_user_id = plus_lab_employee.id.to_s
        t.save

        unless t.errors.full_messages.blank?
            puts "errors #{t.errors.full_messages} while creating tag"
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        report_id = nil

        Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
            report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
            report.created_by_user = plus_lab_employee
            report.created_by_user_id = plus_lab_employee.id.to_s
            report.tests[0].template_tag_ids << t.id.to_s
            report.save
            report_id = report.id.to_s
            assert_equal true, report.errors.full_messages.blank?
            break
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        r = Diagnostics::Report.find(report_id)
        #puts r.tests[0].ranges[0].tags.to_s
        #exit(1)
        
        r.tests[0].template_tag_ids = []

        put diagnostics_report_path(r.id.to_s), params: {report: r.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

        assert_equal "204",response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        r = Diagnostics::Report.find(r.id.to_s)

        assert_equal r.tests[0].tags.size, 0

    end

end