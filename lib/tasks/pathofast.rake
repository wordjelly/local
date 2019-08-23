namespace :pathofast do
  desc "TODO"
  task recreate_indices: :environment do
  	["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","Business::Order","Patient","Diagnostics::Report","Image","Schedule::Minute","Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
      "Inventory::Equipment::MachineComplaint"].each do |cls|
  		puts "creating index for :#{cls}"
  		cls.constantize.send("create_index!",{force: true})
  	end
  	User.es.index.reset
  end
  task recreate_inventory_indices: :environment do 
  	["Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
  		"Inventory::Equipment::MachineComplaint"].each do |cls|
  		puts "creating index for :#{cls}"
  		cls.constantize.send("create_index!",{force: true})
  	end
  end

  task website_setup: :environment do 

    ["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","Business::Order","Patient","Diagnostics::Report","Image","Schedule::Minute", "Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
      "Inventory::Equipment::MachineComplaint"].each do |cls|
      puts "creating index for :#{cls}"
      cls.constantize.send("create_index!",{force: true})
    end
    User.delete_all
    User.es.index.reset

    Tag.create_default_employee_roles

    Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"



    ## this is a lab user
    u1 = User.new(email: "pathofast@gmail.com", password: "cocostan", confirmed_at: Time.now)
    u1.save
    u1.confirm
    u1.save

    Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
    pathofast.save 
    puts "ERRORS CREATING PATHOFAST: #{pathofast.errors.full_messages}"

    Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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

    ## add some tags
   
  end

end
