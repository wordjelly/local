require "test_helper"
require 'helpers/test_helper'
class OrderAccessibilityTest < ActionDispatch::IntegrationTest

    include TestHelper

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
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

    end

=begin
    ## should this have the sign ?
    test "consent to perform test" do 

    end

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

    ## TODO 15th
    test " order has option for home visit -> tags on the order " do 


    end

    ## TODO 15th
    ## so order also has tags
    ## like phlebotomy-visit/collection-visit
    test " order has option for techinician visit to doctor -> tags on the order" do 

    end

    ######################################################

    test " order has option for delivery boy visit to doctor/another lab " do 

    end

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
    ## so you can choose users from your organization
    ## so these are basically user ids.
    ## to send the reports to
    ## to send the report to a different doctor/user
    ## you can choose them by name.
    ## or add bare numbers or emails
    ## so that setting should be there on the order level
    ## or on the 
    ## it should also send the copy to the email of the creating users organizations.
    ## so we define these as organization level settings.
    ## get on with this shit instantly.
    ## we add an array called recipients
    ## user_id / mobile / email
    ## if user id is defined, then no mobile or email needs to be given.
    ## otherwise either or both can be given.
    ## should accept a resend_to this user button.
    ## so that will also work.
    ## we can nest these objects under notification
    ## as a module.
    ## i can manage these 
    ##
    ########################################################,
    test " can define at the organization / patient level, to always send reports to certain people " do 


    end

    test " patient can add doctors emails to send the report " do 

    end

    test " other lab can also add these emails " do 

    end

    test " can choose users from existing organization to send the report to " do 

    end

    test " can resend the report by means of an attr_accessor, to some parties, for eg mark some parties to resend the report to setting " do 

    end

    test " can disable a certain additional recipient from being sent the notification " do 
        
    end

=end

end