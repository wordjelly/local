namespace :pathofast do
  desc "TODO"

    task week: :environment do 
        l = JSON.parse($redis.get("week_changes_obj"))
        IO.write("jj.json",JSON.pretty_generate(l))
    end
    
    task auth_issue: :environment do

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
        
        @headers = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @u.authentication_token, "X-User-Es" => @u.client_authentication["testappid"], "X-User-Aid" => "testappid"}
        puts "api key: #{@ap_key}"
        puts "the headers are:"
        puts @headers.to_s

    end

    ## and we wanna add the reports
    ## basically that too.

    task recreate_indices: :environment do
  	    JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.reset

        Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
    end

    task recreate_inventory_indices: :environment do 
      	JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
    end

    task statement_setup: :environment do

        JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.reset

        tags = Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ##########################################################
        ##
        ##
        ## CREATE USERS
        ##
        ## should generate the list of users.
        ##
        ##########################################################
        Dir.glob(Rails.root.join('test','test_json_models','users','*.json')).each do |user_file_name|
            basename = File.basename(user_file_name,".json")
            user = User.new(JSON.parse(IO.read(user_file_name))["users"][0])
            user.save
            user.confirm
            user.save
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            user = User.find(user.id.to_s)
            ## create the organization.
            organization = Organization.new(JSON.parse(IO.read(Rails.root.join('test','test_json_models','organizations',"#{basename}.json")))["organizations"][0])
            organization.created_by_user = user
            organization.created_by_user_id = user.id.to_s
            organization.who_can_verify_reports = [user.id.to_s]
            organization.role = Organization::LAB
            organization.save 
            unless organization.errors.full_messages.blank?
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

        latika_sawant = User.where(:email => "latika.sawant@gmail.com").first
        bhargav_raut = User.where(:email => "bhargav.r.raut@gmail.com").first
        arif_shaikh = User.where(:email => "arif.shaikh@gmail.com").first

        
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

        o.template_report_ids = Diagnostics::Report.find_reports_by_organization_name("Pathofast").map{|c| c.id.to_s}
        o.created_by_user = latika_sawant
        o.created_by_user_id = latika_sawant.id.to_s
        o.patient_id = patient.id.to_s
        o.skip_pdf_generation = true
        o.save

        unless o.errors.blank?
            puts o.errors.full_messages
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        #################### CREATE PATIENT FROM ARIF SHAIKH ####################
            
        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
        patient.first_name += "kondhwa"
        patient.mobile_number = rand.to_s[2..11].to_i
        patient.created_by_user = arif_shaikh
        patient.created_by_user_id = arif_shaikh.id.to_s
        patient.save
        puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.new

        o.template_report_ids = Diagnostics::Report.find_reports_by_organization_name("Pathofast").map{|c| c.id.to_s}
        o.created_by_user = arif_shaikh
        o.created_by_user_id = arif_shaikh.id.to_s
        o.patient_id = patient.id.to_s
        o.skip_pdf_generation = true
        o.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        #####################

        20.times do |n|
            patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
            patients = JSON.parse(IO.read(patients_file_path))
            patient = Patient.new(patients["patients"][0])
            patient.first_name += n.to_s
            patient.mobile_number = rand.to_s[2..11].to_i
            patient.created_by_user = bhargav_raut
            patient.created_by_user_id = bhargav_raut.id.to_s
            patient.save
            puts "ERRORS CREATING Aditya Raut Patient #{n}: #{patient.errors.full_messages}"
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

            o = Business::Order.new

            o.template_report_ids = Diagnostics::Report.find_reports_by_organization_name("Pathofast").map{|c| c.id.to_s}
            o.created_by_user = bhargav_raut
            o.created_by_user_id = bhargav_raut.id.to_s
            o.patient_id = patient.id.to_s
            o.skip_pdf_generation = true
            o.save
            unless o.errors.full_messages.blank?
                puts "--------- ERRORS --------------"
                puts o.errors.full_messages
                exit(1)
            end

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

        puts "reached the end of statement setup-------------"

    end

    ## the next step is to write some controller tests.
    ## who can make the payment.
    ## can you add the payment if you don't belong.
    ## stuff like
    ## who can see the shit.
    ## can you make a balance payment if 

    task website_setup: :environment do 

        ["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","Business::Order","Patient","Diagnostics::Report","Image","Schedule::Minute", "Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
          "Inventory::Equipment::MachineComplaint","Credential"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.reset

        Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"



        ## this is a lab user
        u1 = User.new(email: "pathofast@gmail.com", password: "cocostan", confirmed_at: Time.now)
        u1.first_name = "Bhargav"
        u1.last_name = "Raut"
        u1.save
        u1.confirm
        u1.save
        ## so in this case, the type has to be set 
        ## and by default it is becoming document.
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        ## so this is a pretty major problem.
        ## refresh the fucking index, i have no idea what is happening here.
        
        

       
        ## this is a supplier
        u2 = User.new(email: "anand_chem@gmail.com", password: "cocostan", confirmed_at: Time.now)
        u2.save
        u2.confirm
        u2.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        
        ## this is another lab.
        u3 = User.new(email: "icantremember111@gmail.com", password: "cocostan", confirmed_at: Time.now)
        u3.save
        u3.confirm
        u3.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## now we make the organizaitons.
        pathofast = Organization.new
        pathofast.name = "Pathofast Diagnostic Laboratory"
        pathofast.description = "Good Lab"
        pathofast.role = Organization::LAB
        pathofast.created_by_user_id = u1.id.to_s
        pathofast.created_by_user = u1
        pathofast.phone_number = "9561137096"
        pathofast.who_can_verify_reports = [u1.id.to_s]
        pathofast.save 
        puts "ERRORS CREATING PATHOFAST: #{pathofast.errors.full_messages}"

        

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"


        u1 = User.find(u1.id.to_s)
        ## GENERATE A CREDENTIAL FOR DR.BHARGAV/PATHOFAST
        bhargav_credential = Credential.new
        bhargav_credential.user_id = u1.id.to_s
        bhargav_credential.qualifications = ["MBBS","DCP(Pathology)"]
        bhargav_credential.registration_number = "2015052372"
        bhargav_credential.created_by_user_id = u1.id.to_s
        bhargav_credential.created_by_user = u1
        bhargav_credential.save

         ## NOW IF WE MAKE AN ORDER WE CAN EXPERIMENT A BIT.

        puts "ERRORS SAVING CREDENTIAL : #{bhargav_credential.errors.full_messages}"
        #exit(1)

        ## now we make the supplier .
        ## first sort out lab view paths.
        anand = Organization.new
        anand.name = "Anand Chemiceutics"
        anand.description = "Good Distributor"
        anand.role = Organization::SUPPLIER
        anand.phone_number = "02024411990"
        anand.created_by_user_id = u2.id.to_s
        anand.created_by_user = u2
        anand.save 
        puts "ERRORS CREATING ANAND: #{anand.errors.full_messages}"    

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        u1 = User.find(u1.id.to_s)
        u2 = User.find(u2.id.to_s)
        u3 = User.find(u3.id.to_s)
        

        ## create a report by pathofast.
        reports_file_path = Rails.root.join('test','test_json_models','diagnostics','reports','hemogram.json')
        reports = JSON.parse(IO.read(reports_file_path))
        hemogram_report = Diagnostics::Report.new(reports["reports"][0])
        hemogram_report.created_by_user = u1
        hemogram_report.created_by_user_id = u1.id.to_s
        hemogram_report.save
        puts "ERRORS CREATING HEMOGRAM REPORT: #{hemogram_report.errors.full_messages}"    

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## create a patient by pathofast.
        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
        patient.created_by_user = u1
        patient.created_by_user_id = u1.id.to_s
        patient.save
        puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## can we create an order ?
        ## automatically or not ?

    end

    task issue: :environment do 
        b = Business::Order.new
        b.reports << Diagnostics::Report.new
        puts b.pluck_to_hash
    end


    task lis_setup: :environment do 

        ["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","Business::Order","Patient","Diagnostics::Report","Image","Schedule::Minute", "Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
          "Inventory::Equipment::MachineComplaint","Credential"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.reset

        Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"


        ## this is a lab user
        u1 = User.new(email: "pathofast@gmail.com", password: "cocostan", confirmed_at: Time.now)
        u1.first_name = "Bhargav"
        u1.last_name = "Raut"
        u1.save
        u1.confirm
        u1.save
        ## so in this case, the type has to be set 
        ## and by default it is becoming document.
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        ## so this is a pretty major problem.
        ## refresh the fucking index, i have no idea what is happening here.
        ## this is a supplier
        u2 = User.new(email: "anand_chem@gmail.com", password: "cocostan", confirmed_at: Time.now)
        u2.save
        u2.confirm
        u2.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        
        ## this is another lab.
        u3 = User.new(email: "icantremember111@gmail.com", password: "cocostan", confirmed_at: Time.now)
        u3.save
        u3.confirm
        u3.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## now we make the organizaitons.
        pathofast = Organization.new
        pathofast.name = "Pathofast Diagnostic Laboratory"
        pathofast.description = "Good Lab"
        pathofast.role = Organization::LAB
        pathofast.created_by_user_id = u1.id.to_s
        pathofast.created_by_user = u1
        pathofast.phone_number = "9561137096"
        pathofast.who_can_verify_reports = [u1.id.to_s]
        pathofast.lis_security_key = "pathofast"
        pathofast.save 
        puts "ERRORS CREATING PATHOFAST: #{pathofast.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        u1 = User.find(u1.id.to_s)
        ## GENERATE A CREDENTIAL FOR DR.BHARGAV/PATHOFAST
        bhargav_credential = Credential.new
        bhargav_credential.user_id = u1.id.to_s
        bhargav_credential.qualifications = ["MBBS","DCP(Pathology)"]
        bhargav_credential.registration_number = "2015052372"
        bhargav_credential.created_by_user_id = u1.id.to_s
        bhargav_credential.created_by_user = u1
        bhargav_credential.save

         ## NOW IF WE MAKE AN ORDER WE CAN EXPERIMENT A BIT.

        puts "ERRORS SAVING CREDENTIAL : #{bhargav_credential.errors.full_messages}"
        #exit(1)

        ## now we make the supplier .
        ## first sort out lab view paths.
        anand = Organization.new
        anand.name = "Anand Chemiceutics"
        anand.description = "Good Distributor"
        anand.role = Organization::SUPPLIER
        anand.phone_number = "02024411990"
        anand.created_by_user_id = u2.id.to_s
        anand.created_by_user = u2
        anand.who_can_verify_reports = [u2.id.to_s]
        anand.lis_security_key = "anand"
        anand.save 
        puts "ERRORS CREATING ANAND: #{anand.errors.full_messages}"    

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        u2 = User.find(u2.id.to_s)
        ## GENERATE A CREDENTIAL FOR DR.BHARGAV/PATHOFAST
        jayesh_credential = Credential.new
        jayesh_credential.user_id = u2.id.to_s
        jayesh_credential.qualifications = ["MBBS","MD(Pathology)"]
        jayesh_credential.registration_number = "2015052513"
        jayesh_credential.created_by_user_id = u2.id.to_s
        jayesh_credential.created_by_user = u2
        jayesh_credential.save
        
        unless jayesh_credential.errors.full_messages.blank?
            
            puts "ERRORS SAVING CREDENTIAL : #{jayesh_credential.errors.full_messages}"
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
       
        u1 = User.find(u1.id.to_s)
        u2 = User.find(u2.id.to_s)
        u3 = User.find(u3.id.to_s) 

       
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## CREATES ALL THE RPEORTS.
        ## NOW CREATE AN ORDERS
        ## AND A PATIENT.
        report_ids = []
        ["hemogram","urea","creatinine"].each do |report_name|
            file_path = Rails.root.join('test','test_json_models','diagnostics','reports',"#{report_name}.json")
            report = JSON.parse(IO.read(file_path))
            report = Diagnostics::Report.new(report["reports"][0])
            if report_name == "creatinine"
                report.created_by_user = u2
                report.created_by_user_id = u2.id.to_s
            else
                report.created_by_user = u1
                report.created_by_user_id = u1.id.to_s
            end
            report.save
            report_ids << report.id.to_s
            unless report.errors.blank?
                puts "THERE WERE ERRORS CREATING THE REPORT"
                puts report.errors.full_messages
                exit(1)
            end
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"


        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
        patient.created_by_user = u1
        patient.created_by_user_id = u1.id.to_s
        patient.save
        puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.new
        o.template_report_ids = report_ids        
        o.created_by_user = u1
        o.created_by_user_id = u1.id.to_s
        o.patient_id = patient.id.to_s
        o.save
        
        unless o.errors.full_messages.blank?
            puts "Errors creating order:"
            puts o.errors.full_messages
            exit(1)
        end  

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

       
        existing_order = Business::Order.find(o.id.to_s)
        new_hash = {
            :categories => [
                {
                    :items => [
                        {
                            :use_code => "abcd",
                            :code => "abcd"
                        }
                    ]
                },
                {
                    :items => [
                        {
                            :use_code => "1234",
                            :code => "1234"
                        }
                    ]
                }
            ]
        }
        new_hash.assign_attributes(existing_order)

        #puts "these are the changed attributes"
        #puts existing_order.changed_attributes.to_s
        #puts existing_order.categories[0]
        existing_order.created_by_user = u1
        existing_order.save

        puts "reached the end"

    end

    ## esr. gram, afb, pus, urine culture and urine.
    ## these are the main things.
    ## and we are through.
    ## and anti-ccp.
    ## it will read csv from a given file and generate the ranges from that.
    task cbc: :environment do 
        report = Diagnostics::Report.new
        report.name = "Complete Blood Count with Peripheral Smear"
        report.description = "26 parameter blood count, with peripheral thin film smear preparation"
        csv_file_path = Rails.root.join('vendor','assets','csv','complete_blood_count_ranges.csv')
        csv_file = IO.read(csv_file_path)
        test_names = ["WBC","RBC","HGB","HCT","MCV","MCH","MC-HC","RDW%","PLT","MPV","NEU%","LYMPH%","MONO%","EOS%","BASO%","NEU-ABS","LYM-ABS","MONO-ABS","EOS-ABS","BASO-ABS"]
        csv_file.split(/(#{test_names.join("|")})/)[1..-1].each_slice(2) do |slice|
            test_name = slice[0]
            test_text = slice[1]
            test = Diagnostics::Test.new(name: test_name, lis_code: test_name)

            #puts "test name is :#{test_name}"
            #puts "test text is:"
            #puts test_text
            test_text.split(/\n/).each do |range_line|
                cells = range_line.split(/\t/)
                unless cells.blank?
                    #puts "cells are"
                    #puts cells.to_s
                    min_age = cells[0].to_i
                    max_age = cells[3].gsub(/\<|\>/,'')
                    max_age = max_age == "adult" ? 120 : max_age.to_i
                    puts "min age is: #{min_age}, max age is: #{max_age}"
                    min_age_unit = cells[1]
                    max_age_unit = cells[4]
                    puts "min age unit is: #{min_age_unit}, max age unit: #{max_age_unit}"
                    male_range_min_value = cells[5].split("-")[0]
                    male_range_max_value = cells[5].split("-")[1]
                    female_range_min_value = cells[6].split("-")[0]
                    female_range_max_value = cells[6].split("-")[1]

                    ########### FOR MALE.
                    range = Diagnostics::Range.new(sex: "Male")
                    if min_age_unit == "d"
                        range.min_age_days = min_age
                    elsif min_age_unit == "y"
                        range.min_age_years = min_age
                    end

                    if max_age_unit == "d"
                        range.max_age_days = max_age
                    elsif max_age_unit == "y"
                        range.max_age_years = max_age
                    end

                    range.tags << Tag.new(range_type: "normal", min_range_val: male_range_min_value, max_range_val: male_range_max_value)
                    
                    test.ranges << range

                    ########## FOR FEMALE
                    range = Diagnostics::Range.new(sex: "Female")
                    if min_age_unit == "d"
                        range.min_age_days = min_age
                    elsif min_age_unit == "y"
                        range.min_age_years = min_age
                    end

                    if max_age_unit == "d"
                        range.max_age_days = max_age
                    elsif max_age_unit == "y"
                        range.max_age_years = max_age
                    end

                    range.tags << Tag.new(range_type: "normal", min_range_val: female_range_min_value, max_range_val: female_range_max_value)  

                    test.ranges << range
                end
            end
            report.tests << test
        end

        #puts JSON.pretty_generate(report.deep_attributes(true,false))
        cbc_report_path = csv_file_path = Rails.root.join('vendor','assets','pathofast_report_formats','hematology','CBC.json')
        
        IO.write(cbc_report_path,JSON.pretty_generate(report.deep_attributes(true,false)))
    
    end

    task add_pathofast_reports: :environment do 
        Diagnostics::Report.send("create_index!",{force: true})
        u = User.where(:email => "bhargav.r.raut@gmail.com").first
        path = Rails.root.join('vendor','assets','pathofast_report_formats','coagulation','**/*.json')
        Dir.glob(path)[0..2].each do |file|
            r = Diagnostics::Report.new(JSON.parse(IO.read(file)))
            r.created_by_user = u
            r.created_by_user_id = u.id.to_s
            r.save
            unless r.errors.full_messages.blank?
                puts "errors saving report :#{r.name}"
                puts r.errors.full_messages.to_s
            end
        end
    end


    ## now we can test.
    task prepare_ruby_astm_env: :environment do 


        JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.delete
        User.es.index.create
        Auth::Client.delete_all

        tags = Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"


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

        user_file_name = Rails.root.join('test','test_json_models','users','bhargav_raut.json')
        ## now comes the user, organization and inventory creation.
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

        user = User.find(user.id.to_s)


        item_type = Inventory::ItemType.new(JSON.parse(IO.read(Rails.root.join("test","test_json_models","inventory","item_types","BD_Citrate_tube.json"))))
        item_type.created_by_user = user
        item_type.created_by_user_id = user.id.to_s 
        item_type.save
        unless item_type.errors.full_messages.blank?
            puts "Errors saving item type:"
            puts item_type.errors.full_messages
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        item_group = Inventory::ItemGroup.new
        item_group.name = "BD Citrate Tube 100 pcs"
        item_group.group_type = "Consumables"
        item_group.item_definitions = [
            {
                item_type_id: item_type.id.to_s,
                quantity: 100,
                expiry_date: "2020-02-02"
            }   
        ]
        item_group.created_by_user = user
        item_group.created_by_user_id = user.id.to_s
        item_group.save
        unless item_group.errors.full_messages.blank?
            puts "Errors saving item group:"
            puts item_group.errors.full_messages
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## now the next thing is to order this item group.
        ## and to start adding items to it.
        ## order the item group.
        transaction = Inventory::Transaction.new
        transaction.supplier_item_group_id = item_group.id.to_s
        transaction.supplier_id = organization.id.to_s
        transaction.quantity_ordered = 1
        transaction.created_by_user_id = user.id.to_s
        transaction.created_by_user = user
        transaction.save
        unless transaction.errors.full_messages.blank?
            puts "Errors creating transaction:"
            puts transaction.errors.full_messages
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        transaction = Inventory::Transaction.find(transaction.id.to_s)
        transaction.run_callbacks(:find)
        transaction.quantity_received = 1
        transaction.save
        unless transaction.errors.full_messages.blank?
            puts "Errors creating transaction:"
            puts transaction.errors.full_messages
            exit(1)
        end       

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*" 

        ## now we have the local item group.
        ## now we want to find that item group, and add items to it.
        transaction = Inventory::Transaction.find(transaction.id.to_s)
        transaction.run_callbacks(:find)
        local_item_group_id = transaction.local_item_groups[0].id.to_s


        ## now we want to create items with this as the item group.
        ## we create 20 items.
        #######################
        path = Rails.root.join('vendor','assets','pathofast_report_formats','coagulation','**/*.json')
        report_ids = []
        Dir.glob(path)[0..2].each do |file|
            r = Diagnostics::Report.new(JSON.parse(IO.read(file)))
            r.created_by_user = user
            r.created_by_user_id = user.id.to_s
            r.save
            report_ids << r.id.to_s
            unless r.errors.full_messages.blank?
                puts "errors saving report :#{r.name}"
                puts r.errors.full_messages.to_s
                exit(1)
            end
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        #######################
        item_ids = []
        20.times do |n|
            item = Inventory::Item.new
            item.barcode = "abcdefg#{n}"
            item.item_type_id = item_type.id.to_s
            item.expiry_date = "2020-02-02"
            item.categories = item_type.categories
            item.transaction_id = transaction.id.to_s
            item.local_item_group_id = local_item_group_id
            item.created_by_user = user
            item.created_by_user_id = user.id.to_s
            item.save
            # so now we want to group the items by the categories
            # the belong to that item group.
            unless item.errors.full_messages.blank?
                puts "errors saving item: #{item.barcode}"
                puts item.errors.full_messages
                exit(1)
            end
            item_ids << item.id.to_s
        end


        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        ## now create twenty orders, and add the reports and barcodes into them.
        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
        patient.first_name += "plus".to_s
        patient.mobile_number = rand.to_s[2..11].to_i
        patient.created_by_user = user
        patient.created_by_user_id = user.id.to_s
        patient.save
        puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        item_ids.each do |item_id|
            o = Business::Order.new
            o.patient_id = patient.id.to_s
            o.created_by_user = user
            o.created_by_user_id = user.id.to_s
            o.save
           
            unless o.errors.full_messages.blank?
                puts "errors saving order"
                puts o.errors.full_messages
                exit(1)
            else
                Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
                o = Business::Order.find(o.id.to_s)
                o.run_callbacks(:find)
                o.template_report_ids << report_ids
                o.template_report_ids.flatten!
                o.created_by_user = user
                o.save  
                unless o.errors.full_messages.blank?
                    puts "errors saving order"
                    puts o.errors.full_messages
                    exit(1)
                else
                    Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
                    o = Business::Order.find(o.id.to_s)
                    o.run_callbacks(:find)
                    o.categories.first.items << Inventory::Item.find(item_id)
                    o.created_by_user = user
                    o.save
                    unless o.errors.full_messages.blank?
                        puts "errors saving order"
                        puts o.errors.full_messages
                        exit(1)
                    else

                    end
                end
            end
        end
        ######################################################
        ##
        ##
        ## CREATE ONE ORDER WITH SOME REPORTS, BUT WITHOUT ANY BARCODES
        ##
        ##
        ######################################################
        o = Business::Order.new
        o.patient_id = patient.id.to_s
        o.created_by_user = user
        o.created_by_user_id = user.id.to_s
        o.save
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        o = Business::Order.find(o.id.to_s)
        o.run_callbacks(:find)
        o.template_report_ids << report_ids
        o.template_report_ids.flatten!
        o.created_by_user = user
        o.save  
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
    
        organization = Organization.find(organization.id)
    
        puts "LIS KEY:#{organization.lis_security_key}, ORGANIZATION ID:#{organization.id.to_s}"

    end

    task preprocess_pathofast_reports: :environment do 
        path = Rails.root.join('vendor','assets','pathofast_report_formats','**/*.json')
        Dir.glob(path).each do |file|
            begin
                r = Diagnostics::Report.new(JSON.parse(IO.read(file)))
                r.tests.each do |test|
                    test.ranges.each do |range|
                        range.tags.each do |tag|
                            if tag.is_history?
                                tag.nested_id = BSON::ObjectId.new.to_s
                            end
                            if tag.is_trimester_tag?
                                puts "got a trimester tag"
                                range.template_tag_ids << Tag::LMP_TAG_ID
                                test.template_tag_ids << Tag::LMP_TAG_ID
                                puts "Range template tag ids become: #{range.template_tag_ids}"
                                puts "test template tag ids become: #{test.template_tag_ids}"
                            end
                        end
                        range.template_tag_ids.uniq!
                    end
                    test.template_tag_ids.uniq!
                end

                IO.write(Rails.root.join('vendor','assets','processed_report_formats',File.basename(file)),JSON.pretty_generate(r.deep_attributes(false,false)))
        

            rescue => e
                puts e.to_s
                puts "error #{file}"
                exit(1)
            end
        end
    end

end
