require "test_helper"
require 'helpers/payments_receipts_test_helper'
	

class ReportsControllerRangesTest < ActionDispatch::IntegrationTest

    setup do

   		JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          #puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.delete
        User.es.index.create
        Auth::Client.delete_all

        tags = Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        #########################################################
        ##
        ##
        ## CREATING DEVELOPER ACCOUNT AND CLINET.
        ##
        ##
        #########################################################
        #########################################################
        ##
        ##
        ## CREATING DEVELOPER ACCOUNT AND CLINET.
        ##
        ##
        #########################################################
        @u = User.new(email: "developer@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @u.save
        #puts @u.errors.full_messages.to_s
     	#puts @u.authentication_token.to_s
     	#exit(1)
        @u = User.find(@u.id.to_s)
        @u.confirm
        @u.save
        #puts @u.errors.full_messages.to_s
        @u = User.find(@u.id.to_s)
     	#puts @u.authentication_token.to_s
        @c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        @ap_key = @c.api_key
        @u = User.find(@u.id.to_s)

        @u.confirm
        @u.save
        #puts @u.errors.full_messages.to_s
     	#puts @u.authentication_token.to_s
        @c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        @ap_key = @c.api_key

        ## key => user id
        ## value => {auth_token =>  "", client_authentication => ""}
        @security_tokens = {}
        #puts @u.authentication_token.to_s
        #exit(1)
        #########################################################
        ##
        ##
        ## CREATING ALL OTHER USERS.
        ##
        ##
        #########################################################
        Dir.glob(Rails.root.join('test','test_json_models','users','*.json')).each do |user_file_name|
            basename = File.basename(user_file_name,".json")
            user = User.new(JSON.parse(IO.read(user_file_name))["users"][0])
            user.save
            user.confirm
            user.save
            user.client_authentication["testappid"] = BSON::ObjectId.new.to_s
         	user.save
         	@security_tokens[user.id.to_s] = {
         		"authentication_token" => user.authentication_token,
         		"es_token" => user.client_authentication["testappid"]
         	}

            unless user.errors.full_messages.blank?
            	puts "error creating user"
            	exit(1)
            end
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            user = User.find(user.id.to_s)
           		
           	
           	Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
           	
           	## we add it to the organization members,
           	## and thereafter into the organization -> user_ids
           	## that way it will be fine.


            organization = Organization.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','organizations',"#{basename}.json")))["organizations"][0])
            organization.created_by_user = user
            organization.created_by_user_id = user.id.to_s
            organization.who_can_verify_reports = [user.id.to_s]
            organization.role = Organization::LAB
            organization.save 
            unless organization.errors.full_messages.blank?
                puts "errors creating organizaiton--------->"
                puts organization.errors.full_messages.to_s
                exit(1)
            end
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            employee = User.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','employees',"#{basename}.json")))["users"][0])
           	employee.save
           	employee.confirm
           	employee.save
           	employee.client_authentication["testappid"] = BSON::ObjectId.new.to_s
         	employee.save
         	
           	unless employee.errors.full_messages.blank?
           		puts "errors creating employee"
           		exit(1)
           	end
            employee.organization_members << OrganizationMember.new(organization_id: organization.id.to_s, employee_role_id: tags.keys[0])
            employee.save
            unless employee.errors.full_messages.blank?
            	puts "errors saving employee with organization member"
            	exit(1)
            end
            @security_tokens[employee.id.to_s] = {
         		"authentication_token" => employee.authentication_token,
         		"es_token" => employee.client_authentication["testappid"]
         	}
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            organization = Organization.find(organization.id.to_s)
            organization.run_callbacks(:find)
            user = User.find(user.id.to_s)
            organization.created_by_user = user
            organization.created_by_user_id = user.id.to_s
            organization.user_ids << employee.id.to_s
            organization.save
            unless organization.errors.full_messages.blank?
            	puts "errors saving organiztion with user ids -->"
                puts organization.errors.full_messages.to_s
                exit(1)
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            user = User.find(user.id.to_s)
            ## create the credential.
            credential = Credential.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','credentials',"#{basename}.json")))["credentials"][0])
            credential.created_by_user = user
            credential.created_by_user_id = user.id.to_s
            credential.user_id = user.id.to_s
            credential.save 
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            user = User.find(user.id.to_s)
            Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
                report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
                report.created_by_user = user
                report.created_by_user_id = user.id.to_s
                report.save
                unless report.errors.full_messages.blank?
                   # puts "Report name is: #{report.name.to_s}"
                    puts report.errors.full_messages.to_s
                    exit(1)
                end
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

    end

    test " error if no range accounts for an age category, while  adding a test " do 
            
        plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

        report = load_error_report("age_range_missing")

        post diagnostics_report_path report, params: {report: report.attributes, :api_key => @ap_key, :current_app_id => "testappid"}.to_json, headers: get_user_headers(@security_tokens.plus_lab_employees)

        puts response.body.to_s

    end

    ## let me finish this.
    ## and i want to see why the scoring is so shitty.

=begin
    test " error if no range accounts for a particular gender, while adding a test " do
        
        ## you want to create a report.

    end

    test " error if range overlaps for a particular gender " do 
    end

    test " inference must be defined for abnormal ranges " do 
      
    end

    test " ignores range interpreation if the option is defined, and only prints all the ranges for that gender " do 

    end
=end

    ## what all should be done today ?
    ## history and range interpretation and showing them as a dropdown
    ## are required
    ## and order finalization.
    ## then accessibility, balance, top up and payments.
    ## if i went to run now -> minimum 9 till i come back.
    ## 
    
end
