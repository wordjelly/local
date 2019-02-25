namespace :pathofast do
  desc "TODO"
  task recreate_indices: :environment do
  	["Test","Employee","Item","ItemGroup","ItemRequirement","ItemType","Location","NormalRange","Order","Patient","Report","Status","Test"].each do |cls|
  		cls.constantize.send("create_index!",{force: true})
  	end
  end

end
