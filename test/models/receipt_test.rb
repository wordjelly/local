require 'test_helper'
 
class ReceiptTest < ActiveSupport::TestCase
   	
   	## if you run tests, then here is where we can test it out pretty decently well.
    setup do 
    	JSON.parse(IO.read(Rails.root.join("vendor","assets","others","es_index_classes.json")))["es_index_classes"].each do |cls|
          puts "creating index for :#{cls}"
          cls.constantize.send("create_index!",{force: true})
        end
        User.delete_all
        User.es.index.reset

        Tag.create_default_employee_roles

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"


        ## this is a lab user
        @u1 = User.new(email: "pathofast@gmail.com", password: "cocostan", confirmed_at: Time.now)
        @u1.first_name = "Bhargav"
        @u1.last_name = "Raut"
        @u1.save
        @u1.confirm
        @u1.save
        ## so in this case, the type has to be set 
        ## and by default it is becoming document.
        
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        ## so this is a pretty major problem.
        ## refresh the fucking index, i have no idea what is happening here.
        ## this is a supplier
        @u2 = User.new(email: "anand_chem@gmail.com", password: "cocostan", confirmed_at: Time.now)
        @u2.save
        @u2.confirm
        @u2.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
        
        ## this is another lab.
        @u3 = User.new(email: "icantremember111@gmail.com", password: "cocostan", confirmed_at: Time.now)
        @u3.save
        @u3.confirm
        @u3.save

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ## now we make the organizaitons.
        @pathofast = Organization.new
        @pathofast.name = "Pathofast Diagnostic Laboratory"
        @pathofast.description = "Good Lab"
        @pathofast.role = Organization::LAB
        @pathofast.created_by_user_id = @u1.id.to_s
        @pathofast.created_by_user = @u1
        @pathofast.phone_number = "9561137096"
        @pathofast.who_can_verify_reports = [@u1.id.to_s]
        @pathofast.lis_security_key = "pathofast"
        @pathofast.save 
        puts "ERRORS CREATING PATHOFAST: #{@pathofast.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        @u1 = User.find(@u1.id.to_s)
        ## GENERATE A CREDENTIAL FOR DR.BHARGAV/PATHOFAST
        @bhargav_credential = Credential.new
        @bhargav_credential.user_id = @u1.id.to_s
        @bhargav_credential.qualifications = ["MBBS","DCP(Pathology)"]
        @bhargav_credential.registration_number = "2015052372"
        @bhargav_credential.created_by_user_id = @u1.id.to_s
        @bhargav_credential.created_by_user = @u1
        @bhargav_credential.save

         ## NOW IF WE MAKE AN ORDER WE CAN EXPERIMENT A BIT.

        puts "ERRORS SAVING CREDENTIAL : #{@bhargav_credential.errors.full_messages}"
        #exit(1)

        ## now we make the supplier .
        ## first sort out lab view paths.
        @anand = Organization.new
        @anand.name = "Anand Chemiceutics"
        @anand.description = "Good Distributor"
        @anand.role = Organization::SUPPLIER
        @anand.phone_number = "02024411990"
        @anand.created_by_user_id = @u2.id.to_s
        @anand.created_by_user = @u2
        @anand.who_can_verify_reports = [@u2.id.to_s]
        @anand.lis_security_key = "anand"
        @anand.save 
        puts "ERRORS CREATING ANAND: #{@anand.errors.full_messages}"    

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        @u2 = User.find(@u2.id.to_s)
        ## GENERATE A CREDENTIAL FOR DR.BHARGAV/PATHOFAST
        @jayesh_credential = Credential.new
        @jayesh_credential.user_id = @u2.id.to_s
        @jayesh_credential.qualifications = ["MBBS","MD(Pathology)"]
        @jayesh_credential.registration_number = "2015052513"
        @jayesh_credential.created_by_user_id = @u2.id.to_s
        @jayesh_credential.created_by_user = @u2
        @jayesh_credential.save
        
        unless @jayesh_credential.errors.full_messages.blank?
            
            puts "ERRORS SAVING CREDENTIAL : #{@jayesh_credential.errors.full_messages}"
            exit(1)
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
       
        @u1 = User.find(@u1.id.to_s)
        @u2 = User.find(@u2.id.to_s)
        @u3 = User.find(@u3.id.to_s) 

       
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        ##########################################################
        ##
        ##
        ## CREATE REPORTS AND ORDERS HERE.
        ##
        ##
        ##########################################################

        @reports = {}
        ["hemogram","urea","creatinine"].each do |report_name|
            file_path = Rails.root.join('test','test_json_models','diagnostics','reports',"#{report_name}.json")
            report = JSON.parse(IO.read(file_path))
            report = Diagnostics::Report.new(report["reports"][0])
            if report_name == "creatinine"
                report.created_by_user = @u2
                report.created_by_user_id = @u2.id.to_s
            else
                report.created_by_user = @u1
                report.created_by_user_id = @u1.id.to_s
            end
            report.save
            Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
            @reports[report.name] = Diagnostics::Report.find(report.id.to_s)
            unless report.errors.blank?
                puts "THERE WERE ERRORS CREATING THE REPORT"
                puts report.errors.full_messages
                exit(1)
            end
        end

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"


        patients_file_path = Rails.root.join('test','test_json_models','patients','aditya_raut.json')
        patients = JSON.parse(IO.read(patients_file_path))
        @patient = Patient.new(patients["patients"][0])
        @patient.created_by_user = @u1
        @patient.created_by_user_id = @u1.id.to_s
        @patient.save
        puts "ERRORS CREATING Aditya Raut Patient: #{@patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

    end


	test "Creates A Receipt From the Primary Lab to the Patient for an in house report" do 

  		o = Business::Order.new
        o.template_report_ids = @reports.keys.select{|c| c == "hemogram"}.map{|c| @reports[c].id.to_s}   
        o.created_by_user = @u1
        o.created_by_user_id = @u1.id.to_s
        o.patient_id = @patient.id.to_s
        o.skip_pdf_generation = true
        o.save
        
        unless o.errors.full_messages.blank?
            puts "Errors creating order:"
            puts o.errors.full_messages
            exit(1)
        end  

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)
        
        assert_equal 1, o.receipts.size
        
        first_receipt = o.receipts.first
        puts "the first receipt total is :"
        puts first_receipt.total.to_s
        
        assert_equal @pathofast.id.to_s,first_receipt.payable_to_organization_id 
        
        assert_equal @patient.id.to_s,first_receipt.payable_from_patient_id

        assert_equal @reports["hemogram"].rates.select{|c| c.is_patient_rate? }[0].rate, first_receipt.total
        
  	end 
	
  	test "Creates Two Receipts , one from the outsourced lab to the primary lab, and another from the primary lab to the patient, for an outsourced report " do 

  		o = Business::Order.new
        o.template_report_ids = @reports.keys.select{|c| c == "creatinine"}.map{|c| @reports[c].id.to_s}   
        o.created_by_user = @u1
        o.created_by_user_id = @u1.id.to_s
        o.patient_id = @patient.id.to_s
        o.skip_pdf_generation = true
        o.save
        
        unless o.errors.full_messages.blank?
            puts "Errors creating order:"
            puts o.errors.full_messages
            exit(1)
        end  

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.find(o.id.to_s)
        
        assert_equal 2, o.receipts.size
        
        #first_receipt = o.receipts.first
        
        #assert_equal @pathofast.id.to_s,first_receipt.payable_to_organization_id 
        
        #assert_equal @patient.id.to_s,first_receipt.payable_from_patient_id

        #assert_equal @reports["hemogram"].rates.select{|c| c.is_patient_rate? }[0].rate, first_receipt.total

  	end

   
end