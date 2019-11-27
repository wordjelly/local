require 'test_helper'
 
class StatementTest < ActiveSupport::TestCase
   	
    setup do 
    	
    	JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.reset

        Tag.create_default_employee_roles

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


    test " generates individual statements of all money owed to Pathofast and money owed by Pathofast to 3 other organizations " do 

        latika_sawant = User.where(:email => "latika.sawant@gmail.com").first

        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
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

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        pathofast = Organization.find_organization_by_name("Pathofast")
        plus_path = Organization.find_organization_by_name("Plus Pathology Laboratory")
        #puts "organization is:"
        #puts pathofast.to_s
        #puts "pathofast id is: #{pathofast.id.to_s}"
        ## now for the statement
        s = Business::Statement.new
        s.from = Time.now - 1.year
        s.to = Time.now + 1.month
        s.payable_to_organization_id = pathofast.id.to_s
        ## payable from organization ids.
        s.generate_statement(nil)
        assert_equal 1, s.all_receipts.size
        assert_equal 1, s.payable_from_organization_ids.size
        assert_equal plus_path.id.to_s, s.payable_from_organization_ids.first.payable_from_organization_id

    end

    test " scrolls (individual)payable_from_patient_id aggregation. " do 

        latika_sawant = User.where(:email => "latika.sawant@gmail.com").first
        bhargav_raut = User.where(:email => "bhargav.r.raut@gmail.com").first

        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        patient = Patient.new(patients["patients"][0])
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

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

        pathofast = Organization.find_organization_by_name("Pathofast")
        plus_path = Organization.find_organization_by_name("Plus Pathology Laboratory")

        ## so now let's do it with twenty patients.
        ## so that that
        ## now go for statement.
        s = Business::Statement.new
        s.from = Time.now - 1.year
        s.to = Time.now + 1.month
        s.payable_to_organization_id = pathofast.id.to_s
        s.generate_statement(nil)
        assert_equal 10, s.payable_from_patient_ids.size
        receipt_ids = s.payable_from_patient_ids.map{|c| c.payable_from_patient_id }
        puts "receipt ids are:"
        puts JSON.pretty_generate(receipt_ids)

        s1 = Business::Statement.new
        s1.from = s.from
        s1.to = s.to
        s1.payable_from_patient_id_after = s.payable_from_patient_id_after
        s1.payable_to_organization_id = pathofast.id.to_s
        s1.generate_statement(nil)
        assert_equal 10, s1.payable_from_patient_ids.size
        s1.payable_from_patient_ids.each do |k|
            assert_equal false, (receipt_ids.include? k.payable_from_patient_id.to_s)
        end

    end

    test "scrolls multiple aggregations till the last one ends" do 

        Business::Statement::COMPOSITE_AGGREGATION_SIZE = 1

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

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

        pathofast = Organization.find_organization_by_name("Pathofast")
        plus_path = Organization.find_organization_by_name("Plus Pathology Laboratory")

        
        s = Business::Statement.new
        s.from = Time.now - 1.year
        s.to = Time.now + 1.month
        s.payable_to_organization_id = pathofast.id.to_s
        s.generate_statement(nil)
        assert_equal 1, s.payable_from_patient_ids.size
        assert_equal 1, s.payable_from_organization_ids.size
        payable_from_organization_id = s.payable_from_organization_ids[0].payable_from_organization_id

        s1 = Business::Statement.new
        s1.from = s.from
        s1.to = s.to
        s1.payable_from_patient_id_after = s.payable_from_patient_id_after
         s1.payable_from_organization_id_after = s.payable_from_organization_id_after
        s1.payable_to_organization_id = pathofast.id.to_s
        s1.generate_statement(nil)
        assert_equal 1, s1.payable_from_patient_ids.size
        assert_equal 1, s1.payable_from_organization_ids.size

    end

   
    test "scrolls the all receipts using search after " do 

        
        bhargav_raut = User.where(:email => "bhargav.r.raut@gmail.com").first

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

            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        end

        pathofast = Organization.find_organization_by_name("Pathofast")
        

        ## how many receipts do you expect ?
        ## a total of twenty receipts.
        s = Business::Statement.new
        s.from = Time.now - 1.year
        s.to = Time.now + 1.month
        s.payable_to_organization_id = pathofast.id.to_s
        s.generate_statement(nil)
        assert_equal 10, s.all_receipts.size
        all_receipt_ids = s.all_receipts.map{|c| c.id.to_s}        


        s1 = Business::Statement.new
        s1.from = s.from
        s1.to = s.to
        s1.search_after = s.search_after
        s1.payable_to_organization_id = pathofast.id.to_s
        s1.generate_statement(nil)
        assert_equal 10, s1.all_receipts.size
        s1.all_receipts.each do |k|
            assert_equal false, (all_receipt_ids.include? k.id.to_s)
        end
                
    end

    

end