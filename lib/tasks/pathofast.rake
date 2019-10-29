namespace :pathofast do
  desc "TODO"

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

end
