require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest

	setup do 

	end

	test " -- (WEB)allows new without authentication -- " do 
		get new_organization_path
		assert_equal "200", response.code.to_s
	end

	test " -- (WEB)does not allow create without authentication -- " do 
		post(organizations_path,params: {organization: {name: "hello", address: "goodbye"}})
		## with a web request it will redirect.
		assert_equal "302", response.code.to_s
	end


	test " -- user can create organization -- " do 

	

	end

	test " -- user can delete an organization -- " do 


	end

	test " -- organizations are searchable by name, address, and phone number -- " do 


	end

	test " -- user can request that he be added to an organization -- " do 

	end


	test " -- any existing organization user can approve him -- " do 

	end

	test " -- image can be updated for organization logo -- " do 

	end


	test " -- someone who doesnt belong to the organization can view it -- " do 


	end

	test "-- someone who doesnt belong to the organization cannot modify it in any way -- " do 

	end


	test "-- those who belong to the organization can modify it -- " do 


	end


	test " -- email sent out by user belonging to the organization has its details in the footer of the email -- " do 

	end
	

	test " -- user is notified when he is approved for an organization -- " do 

	end	
	
end