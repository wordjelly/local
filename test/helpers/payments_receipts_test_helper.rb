module PaymentsReceiptsTestHelper

    

	## @return[Business::Order] the order created for the patient from plus path lab.
	def create_plus_path_lab_patient_order
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
        #puts "ERRORS CREATING Aditya Raut Patient: #{patient.errors.full_messages}"

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

        o = Business::Order.new

        o.template_report_ids = Diagnostics::Report.find_reports_by_organization_name("Plus Pathology Laboratory").map{|c| c.id.to_s}
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

end