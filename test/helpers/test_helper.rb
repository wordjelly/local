module TestHelper

    ## @param args[Hash] : shold contain a :user and a :item_group_id
    ## @return[Inventory::ItemGroup] the local item group, cloned in the transaction.
    def order_item_group(args={})
        raise "no item group id or name provided" if args[:item_group_id].blank?
        raise "no user is provided " if args[:user].blank?

        search_results = Inventory::ItemGroup.search({
            size: 1,
                query: {
                    ids: {
                        values: [args[:item_group_id]]
                    }
                }
        })

        unless search_results.response.hits.hits.blank?
            supplier_item_group = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
            supplier_item_group.run_callbacks(:find)
            tr = Inventory::Transaction.new
            tr.supplier_item_group_id = supplier_item_group.id.to_s
            tr.supplier_id = supplier_item_group.supplier_id
            tr.created_by_user = args[:user]
            tr.created_by_user_id = args[:user].id.to_s
            tr.save
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            ## so now you ordered it.
            ## now you get the local item group.
            tr = Inventory::Transaction.find(tr.id.to_s)
            tr.run_callbacks(:find)
            tr.quantity_received = 2
            tr.created_by_user = args[:user]
            tr.created_by_user_id = args[:user].id.to_s
            tr.save
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            tr = Inventory::Transaction.find(tr.id.to_s)
            tr.run_callbacks(:find)
            local_item_group = tr.local_item_groups[0]
            return local_item_group

        else
            raise "no such item group found with id: #{args[:item_group_id]}"
        end

    end

    ## basically take the item_groups -> order them -> 
    def build_transaction_inventory(organization_user)
        Dir.glob(Rails.root.join('test','test_json_models','inventory','item_groups','*.json')).each do |file_name|
            item_group = Inventory::ItemGroup.new(JSON.parse(IO.read(file_name)))
            item_group.created_by_user = organization_user
            item_group.created_by_user_id = organization_user.id.to_s
            item_group.save
            
            unless item_group.errors.full_messages.blank?
                puts "error saving item group in testhelper, method #build_transaction_inventory"
                puts "errors: #{item_group.errors.full_messages}"
                exit(1)
            end

            item_group.item_definitions.each do |id|
                item_type_id = id["item_type_id"]   
                item_type_object = JSON.parse(IO.read(Rails.root.join('test','test_json_models','inventory','item_types',"#{item_type_id}.json")))
                
                item_type = nil
                if item_type_object["item_types"]
                    item_type = Inventory::ItemType.new(item_type_object["item_types"][0])
                else
                    item_type = Inventory::ItemType.new(item_type_object)
                end


                item_type.created_by_user = organization_user
                item_type.created_by_user_id = organization_user.id.to_s
                item_type.save
                unless item_type.errors.full_messages.blank?
                    puts "error saving item type"
                    puts "errors: #{item_type.errors.full_messages}"
                    exit(1)
                end
                Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            end

            ## now we want to make a transaction for the item group.
            tr = Inventory::Transaction.new
            tr.supplier_item_group_id = item_group.id.to_s
            tr.supplier_id = item_group.supplier_id
            tr.created_by_user = organization_user
            tr.created_by_user_id = organization_user.id.to_s
            tr.save
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            tr = Inventory::Transaction.find(tr.id.to_s)
            tr.run_callbacks(:find)
            tr.quantity_received = 2
            tr.created_by_user = organization_user
            tr.created_by_user_id = organization_user.id.to_s
            tr.save
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            ## mark this transaction as received.
            ## and then proceed.

            ## now we have ordered the item group.
            ## now we want to add some items to it.
            ## 
            search_results = Inventory::ItemGroup.search({
            size: 1,
                query: {
                    term: {
                        cloned_from_item_group_id: item_group.id.to_s
                    }
                }
            })

            assert_equal 1, search_results.response.hits.hits.size
            local_item_group = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
            local_item_group.run_callbacks(:find)


            ## so again take the item group and get after it.
            ## so here we have added some items to it.
            ## instead we want one more 
            item_group.item_definitions.each do |id|
                item = Inventory::Item.new
                item.transaction_id = tr.id.to_s
                item.supplier_item_group_id = item_group.id.to_s
                item.local_item_group_id = local_item_group.id.to_s
                item.item_type_id = id["item_type_id"]
                puts "searcing for the item type--------------->#{item.item_type_id}"
                item.categories = Inventory::ItemType.find(id["item_type_id"]).categories
                item.barcode = "12345"
                item.expiry_date = "2025-05-05"
                item.created_by_user = organization_user
                item.created_by_user_id = organization_user.id.to_s
                item.save
                unless item.errors.full_messages.blank?
                    puts "there are errors saving the item."
                    puts "error "
                    puts "errors: #{item.errors.full_messages}"
                    exit(1)
                end
            end

        end
    end

    def build_inventory(organization_user)
        Dir.glob(Rails.root.join('test','test_json_models','inventory','item_types','*.json')).each do |file_name|
            obj =  JSON.parse(IO.read(file_name))
            item_types = obj["item_types"].blank? ? obj : obj["item_types"]
            item_types = [item_types].flatten
            puts "item types are: #{item_types}"
            item_types.each do |item_type_definition|
                item_type = Inventory::ItemType.new(item_type_definition)
                item_type.id = BSON::ObjectId.new.to_s
                item_type.created_by_user = organization_user
                item_type.created_by_user_id = organization_user.id.to_s
                ## so here can be do an alternate version of build inventory ?
                ## where we build item groups -> then transaction -> then you can do more with it.
                ## or you can have item groups predefined.
                ## and then transact on them.
                item_type.save(op_type: 'create')
                if item_type.errors.full_messages.
                    blank?
                    Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
                    JSON.parse(IO.read(Rails.root.join('test','test_json_models','inventory','items',"#{File.basename(file_name)}")))["items"].each do |item_definition|

                        item = Inventory::Item.new(item_definition)
                        item.barcode = BSON::ObjectId.new.to_s
                        item.created_by_user = organization_user
                        item.created_by_user_id = organization_user.id.to_s
                        item.categories = item_type.categories
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

    ## are you pregnant
    ## please choose, the last menstrual period.
    ## then the history answers, will be chosen like that
    ## question is -> days since lmp
    ## please choose only if ---> 
    ## and use attribute for answer ---> 
    ## we do this in the tag.

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

    ## @param[Hash] args : an optional hash of arguments.
    ## expected_structure
    ## 
=begin
    {
        "user_name" => {
            "inventory_folder_path" : "absolute_path/*.json"
            "reports_folder_path" : "absolute_path/*.json",
            "use_transaction_inventory" : true
        }
    }
=end
    def _setup(args={})
        
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
            
            unless args[basename].blank?
                unless args[basename]["use_transaction_inventory"].blank?
                    build_transaction_inventory(user)
                else
                     build_inventory(user)
                end
            else
                 build_inventory(user)
            end

           
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
                
            ## so we are going to sort out history interpretation for thyroid and for beta hcg.
            ## based on the history.
            tags = JSON.parse(IO.read(Rails.root.join('test','test_json_models','tags',"#{basename}.json")))
            unless tags["tags"].blank?
                tags["tags"].each do |tag|
                    t = Tag.new(tag)
                    t.created_by_user = user
                    t.created_by_user_id = user.id.to_s
                    t.save
                    unless t.errors.full_messages.blank?
                        puts "error saving tag:#{tag} in _setup from test_helper.rb"
                        exit(1)
                    end
                end
            end

            reports_folder_path = nil
            #puts "the args are:"
            #puts args.to_s
            if args[basename].blank?
                #puts "args basename is blank"
                reports_folder_path = (Rails.root.join('test','test_json_models','diagnostics','reports','*.json'))
            else
                if args[basename]["reports_folder_path"].blank?
                    reports_folder_path = (Rails.root.join('test','test_json_models','diagnostics','reports','*.json'))
                else
                    reports_folder_path = args[basename]["reports_folder_path"]
                end
            end
            #puts "reports folder path is: #{reports_folder_path}"
            Dir.glob(reports_folder_path).each do |report_file_name|
                puts "report file name:#{report_file_name}"
                json_object = JSON.parse(IO.read(report_file_name))
                json_object = json_object["reports"].blank? ? json_object : json_object["reports"][0]
                report = Diagnostics::Report.new(json_object)
                report.created_by_user = user
                report.created_by_user_id = user.id.to_s
                report.save
                unless report.errors.full_messages.blank?
                    puts "errors saving report #{report.name} with errors"
                    puts report.errors.full_messages
                    exit(1)
                end
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        end

        ActionMailer::Base.deliveries = []
        Auth.configuration.stub_otp_api_calls
        k = $redis.set("security_tokens",JSON.generate(@security_tokens))
        k = $redis.set("ap_key",@ap_key)
        #puts "wrote to redis response: #{k}"
        #exit(1)
    end

    def load_error_report(file_name_without_path_or_extension)
        report = Diagnostics::Report.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','diagnostics','error_reports',"#{file_name_without_path_or_extension}.json")))["reports"][0])
        report
    end

    def load_valid_report(file_name_without_path_or_extension)
        report = Diagnostics::Report.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','diagnostics','reports',"#{file_name_without_path_or_extension}.json")))["reports"][0])
        report
    end

    def build_pathofast_patient_order(template_report_ids,patient,user=nil)
        if user.blank?
            user = User.where(:email => "priya.hajare@gmail.com").first
        end
        #####################################################
        ##
        ##
        ## CREATE PATIENT
        ##
        ##
        ######################################################
        if patient.blank?
            patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
            patients = JSON.parse(IO.read(patients_file_path))
            patient = Patient.new(patients["patients"][0])
            patient.first_name += "plus".to_s
            patient.mobile_number = rand.to_s[2..11].to_i
            patient.created_by_user = user
            patient.created_by_user_id = user.id.to_s
            patient.save
            puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.new

        o.template_report_ids = (template_report_ids || Diagnostics::Report.find_reports_by_organization_name("Pathofast",100).map{|c| c.id.to_s})

        o.created_by_user = user
        o.created_by_user_id = user.id.to_s
        o.patient_id = patient.id.to_s
        o.skip_pdf_generation = true
        o

    end

    ## @param[Array] template_report_ids : 
    ## @return[Business::Order] the order created for the patient from plus path lab.
    ## test each report
    ## auto interpretation -> history -> pdf -> email.
    ## all this for the immunoassay reports today itself.
    def create_pathofast_patient_order(template_report_ids=nil,patient=nil)
        o = build_pathofast_patient_order(template_report_ids,patient)
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

    ## @param[Array] template_report_ids : 
    ## @return[Business::Order] the order created for the patient from plus path lab.
    ## test each report
    ## auto interpretation -> history -> pdf -> email.
    ## all this for the immunoassay reports today itself.
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

    ## @params[args]
    ## expected to contain keys
    ## years
    ## months
    ## days
    ## hours
    ## created_by_user
    def create_patient_of_age(args)
        
        years = args["years"] || 0
        months = args["months"] || 0
        days = args["days"] || 0
        hours = args["hours"] || 0
        created_by_user = args["created_by_user"]

        patient = Patient.new
        
        time_now = Time.now
        time_now = time_now - years.years
        time_now = time_now - months.month
        time_now = time_now - days.days
        time_now = time_now - hours.hours

        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
        patient.first_name += "pathofast-".to_s
        patient.mobile_number = rand.to_s[2..11].to_i
        patient.date_of_birth = time_now
        patient.created_by_user = created_by_user
        patient.created_by_user_id = created_by_user.id.to_s

        patient.save

        patient        

    end

	## @return[Hash]
	def get_user_headers(security_tokens,user)
        puts "the user id is: #{user.id.to_s}"
        puts "security tokens are:"
        puts security_tokens[user.id.to_s]
		{ "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => security_tokens[user.id.to_s]["authentication_token"], "X-User-Es" => security_tokens[user.id.to_s]["es_token"], "X-User-Aid" => "testappid"}
	end

    ## and we can have a common setup also.

end