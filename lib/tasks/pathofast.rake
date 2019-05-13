namespace :pathofast do
  desc "TODO"
  task recreate_indices: :environment do
  	["Employee","Item","ItemGroup","ItemRequirement","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Location","NormalRange","Order","Patient","Report","Status","Test","Image","Minute","Organization"].each do |cls|
  		puts "creating index for :#{cls}"
  		cls.constantize.send("create_index!",{force: true})
  	end
  end
end
