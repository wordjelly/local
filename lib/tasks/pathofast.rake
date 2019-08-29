namespace :pathofast do
  desc "TODO"
  task recreate_indices: :environment do
  	["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","Business::Order","Patient","Diagnostics::Report","Image","Schedule::Minute","Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
      "Inventory::Equipment::MachineComplaint","Credential"].each do |cls|
  		puts "creating index for :#{cls}"
  		cls.constantize.send("create_index!",{force: true})
  	end
  	User.es.index.reset
  end
  task recreate_inventory_indices: :environment do 
  	["Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
  		"Inventory::Equipment::MachineComplaint","Credential"].each do |cls|
  		puts "creating index for :#{cls}"
  		cls.constantize.send("create_index!",{force: true})
  	end
  end

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

    ## okay so the report is being generated
    ## time to look at payments ?
    ## do we work on that ?
    ## or what is most critical ?
    ## i can do payments, and rates visibitilty
    ## this is one module, that pends. 
    ## or tube accession.

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

end
