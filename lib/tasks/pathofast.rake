namespace :pathofast do
  desc "TODO"
  task recreate_indices: :environment do
  	["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","NormalRange","Order","Patient","Report","Status","Image","Minute","Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
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
end
