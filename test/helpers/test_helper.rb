module TestHelper

    def build_inventory(organization_user)
        Dir.glob(Rails.root.join('test','test_json_models','inventory','item_types','*.json')).each do |file_name|
            JSON.parse(IO.read(file_name))["item_types"].each do |item_type_definition|
                item_type = Inventory::ItemType.new(item_type_definition)
                item_type.created_by_user = organization_user
                item_type.created_by_user_id = organization_user.id.to_s
                item_type.save(op_type: 'create')
                if item_type.errors.full_messages.
                    blank?
                    Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
                    #puts "path is:"
                    #puts Rails.root.join('test','test_json_models','inventory','items',"#{File.basename(file_name)}")
                    #puts JSON.parse(IO.read(Rails.root.join('test','test_json_models','inventory','items',"#{file_name}")))
                    #exit(1) 
                    JSON.parse(IO.read(Rails.root.join('test','test_json_models','inventory','items',"#{File.basename(file_name)}")))["items"].each do |item_definition|

                        item = Inventory::Item.new(item_definition)
                        item.barcode = BSON::ObjectId.new.to_s
                        item.created_by_user = organization_user
                        item.created_by_user_id = organization_user.id.to_s
                        item.item_type_id = item_type.id.to_s
                        item.save(op_type: 'create')
                        unless item.errors.full_messages.blank?
                            puts item.errors.full_messages
                            puts "error trying to create item : #{file_name}"
                            exit(1)
                        end
                    end
                else
                    puts "error trying to create item: #{file_name}"
                    exit(1)
                end
            end
        end
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        #exit(1)
    end

    def add_value_to_order(order,plus_lab_employee,test_index=0,value=15)

        order.reports[0].tests[test_index].result_raw = value

        order = merge_changes_and_save(Business::Order.find(order.id.to_s),order,plus_lab_employee)             
        unless order.errors.full_messages.blank?
            puts "Errors adding normal value to order"
            exit(1)
        end

        order

    end


    def create_order_and_add_tube(report,plus_lab_employee)

        order = create_plus_path_lab_patient_order(report.id.to_s)

        order = Business::Order.find(order.id.to_s)

        # we have to find an item that fits that report.
        # so the report requirement.
        organization_items = Inventory::Item.find_organization_items(plus_lab_employee.organization_members[0].organization_id)

        order.categories[0].items.push(organization_items.first)

        order = merge_changes_and_save(Business::Order.find(order.id.to_s),order,plus_lab_employee)  

        unless order.errors.full_messages.blank?
            puts "error creating order"
            exit(1)
        end 

        order

    end

    def create_required_text_history_tag(user)
        t = build_required_text_history_tag(user)
        t.save
        unless t.errors.full_messages.blank?
            puts "TestHelper:there were errors saving the required history tag"
            exit(1)
        end
        t
    end

    def build_required_text_history_tag(user)
        t = Tag.new
        t.name = "one"
        t.range_type = Tag::HISTORY
        t.description = "Are you a smoker"
        t.history_options = [Tag::YES.to_s,Tag::NO.to_s]
        t.option_must_be_chosen = Tag::YES
        t.created_by_user = user
        t.created_by_user_id = user.id.to_s
        t
    end

    def create_required_number_history_tag(user)
        t = build_required_number_history_tag(user)
        t.save
        unless t.errors.full_messages.blank?
            puts "TestHelper:there were errors saving the required history number tag"
            exit(1)
        end
        t
    end

    def build_required_number_history_tag(user)
        t = Tag.new
        t.name = "one"
        t.range_type = Tag::HISTORY
        t.description = "How many days since you last smoked"
        t.history_options = []
        t.option_must_be_chosen = Tag::YES
        t.created_by_user = user
        t.created_by_user_id = user.id.to_s
        t
    end

    def _setup
        
        JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.delete
        User.es.index.create
        Auth::Client.delete_all

        tags = Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        #######################################################
        ## essential -> make the thing to mark as pass fail
        ## allocate work to someone
        ## zacharias stream
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
            ## so we add God as a default recipient on all organizations
            ## for the purpose of testing.
            organization.recipients << Notification::Recipient.new(email_ids: ["god@gmail.com"])
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
            build_inventory(user)
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            Dir.glob(Rails.root.join('test','test_json_models','diagnostics','reports','*.json')).each do |report_file_name|
                report = Diagnostics::Report.new(JSON.parse(IO.read(report_file_name))["reports"][0])
                report.created_by_user = user
                report.created_by_user_id = user.id.to_s
                report.save
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        end

        ActionMailer::Base.deliveries = []
        Auth.configuration.stub_otp_api_calls
        
    end

    def load_error_report(file_name_without_path_or_extension)
        report = Diagnostics::Report.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','diagnostics','error_reports',"#{file_name_without_path_or_extension}.json")))["reports"][0])
        report
    end

    def load_valid_report(file_name_without_path_or_extension)
        report = Diagnostics::Report.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','diagnostics','reports',"#{file_name_without_path_or_extension}.json")))["reports"][0])
        report
    end



    ## @return[Business::Order] o 
    ## just assembles the order.
    ## @param[Array] template_report_ids
    def build_plus_path_lab_patient_order(template_report_ids=nil)
        latika_sawant = User.where(:email => "latika.sawant@gmail.com").first
        ######################################################
        ##
        ##
        ## CREATE PATIENT
        ##
        ##
        ######################################################
        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
        patient.first_name += "plus".to_s
        patient.mobile_number = rand.to_s[2..11].to_i
        patient.created_by_user = latika_sawant
        patient.created_by_user_id = latika_sawant.id.to_s
        patient.save
        puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.new

        o.template_report_ids = (template_report_ids || Diagnostics::Report.find_reports_by_organization_name("Plus Pathology Laboratory").map{|c| c.id.to_s})

        o.created_by_user = latika_sawant
        o.created_by_user_id = latika_sawant.id.to_s
        o.patient_id = patient.id.to_s
        o.skip_pdf_generation = true
        o
        puts "returning freshly built order"
        puts "it is :#{o.id.to_s}"
        o
    end
        
    ## @param[Array] template_report_ids : 
	## @return[Business::Order] the order created for the patient from plus path lab.
	def create_plus_path_lab_patient_order(template_report_ids=nil)
		o = build_plus_path_lab_patient_order(template_report_ids)
        puts "the created by user organization -> created by user is not getting loaded. "
        o.save

        unless o.errors.blank?
            puts "error creating plus path lab patient order------------------>"
            puts o.errors.full_messages
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o
	end

    ## returns the order
    ## First do this.
    def setup_order_for_update(order,created_by_user)
        created_by_user.run_callbacks(:find)
        order.created_by_user_id = created_by_user.id.to_s
        order.created_by_user = created_by_user
        order.run_callbacks(:find)
        order
    end

    ## saves and returns the order.
    def merge_changes_and_save(existing_order,changed_order,created_by_user) 
        existing_order.created_by_user_id = created_by_user.id.to_s
        existing_order.created_by_user = created_by_user
        existing_order.run_callbacks(:find)
        changed_order.deep_attributes(true).assign_attributes(existing_order)
        existing_order.created_by_user_id = created_by_user.id.to_s
        existing_order.created_by_user = created_by_user
        
        existing_order.save
        existing_order
    end

	## @return[Hash]
	def get_user_headers(security_tokens,user)
		{ "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => security_tokens[user.id.to_s]["authentication_token"], "X-User-Es" => security_tokens[user.id.to_s]["es_token"], "X-User-Aid" => "testappid"}
	end

    ## and we can have a common setup also.

end