require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest

	setup do 
		Organization.create_index! force: true
		NormalRange.create_index! force: true
		Tag.create_index! force: true
		Barcode.create_index! force: true
		Inventory::ItemType.create_index! force: true
		Inventory::ItemGroup.create_index! force: true
		Inventory::Item.create_index! force: true
		Inventory::Transaction.create_index! force: true
		Inventory::ItemTransfer.create_index! force: true
		Inventory::Comment.create_index! force: true
		## that's the end of it
		User.delete_all
		User.es.index.delete
		User.es.index.create
        Auth::Client.delete_all
        #########################################################
        ##
        ##
        ## PATHOFAST USERS
        ##
        ##
        #########################################################
        @u = User.new(email: "bhargav.r.raut@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @u.save
        @u = User.find(@u.id.to_s)
        @u.confirm
        @u.save
        @u2 = User.new(email: "icantremember111@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @u2.save
        @u2 = User.find(@u2.id.to_s)
        @u2.confirm
        @u2.save
		@c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        @u2.client_authentication["testappid"] = "test_es_token_two"
        @u2.save
        @ap_key = @c.api_key

        #########################################################
        ##
        ##
        ## ROLES
        ## controls also have to be established in diagnostics
        ## at the level of the test object.
        ##
        #########################################################
        @pathologist_role = Tag.new(name: "Pathologist",created_by_user: @u, tag_type: Tag::EMPLOYEE_TAG)
        @pathologist_role.assign_id_from_name
		@pathologist_role.save
		#puts "these are the pathologist role error messages ------------------"
		#puts @pathologist_role.errors.full_messages.to_s
		
		#puts Tag.find("Pathologist")
		
		#exit(1)


		@technician_role = Tag.new(name: "Technician", created_by_user: @u, tag_type: Tag::EMPLOYEE_TAG)
		@technician_role.assign_id_from_name
		@technician_role.save

        ##########################################################
        ##
        ##
        ##
        ## KONDHWA DIAGNOSTIC USERS
        ##
        ##
        ##########################################################
        @atif = User.new(email: "atif@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @atif.save
        @atif = User.find(@atif.id.to_s)
        @atif.confirm
        @atif.save
        @atif.client_authentication["testappid"] = "test_es_token_three"
        @atif.save
        @atif.employee_role_id = "Pathologist"
        @atif.save
        ##########################################################

        puts "-------------- DOING PATHAN ----------------------- "
        @pathan = User.new(email: "pathan@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @pathan.save
        @pathan = User.find(@pathan.id.to_s)
        @pathan.confirm
        @pathan.save
        @pathan.client_authentication["testappid"] = "test_es_token_four"
        @pathan.employee_role_id = "Technician"
        @pathan.save
        #puts @pathan.errors.full_messages.to_s
        #exit(1)


        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		@headers = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @u.authentication_token, "X-User-Es" => @u.client_authentication["testappid"], "X-User-Aid" => "testappid"}

        #@pathan = User.find(@pathan.id.to_s)

        @pathan_headers = {
            "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @pathan.authentication_token, "X-User-Es" => @pathan.client_authentication["testappid"], "X-User-Aid" => "testappid"
        }

    end

=begin
    test " -- creates an organization -- " do 
    	
    	post organizations_path, params: {organization: {name: "first item type", description: "a good lab", address: "a new place", role: "lab", verifiers: 2, phone_number: "9561137096"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

    	puts response.body.to_s

		assert_equal "201", response.code.to_s
    	
    end

    test " -- organization created by the user is found in his member organizations -- " do 

    	post organizations_path, params: {organization: {name: "first item type", description: "a good lab", address: "a new place", role: "lab", verifiers: 2, phone_number: "9561137096"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

    	puts response.body.to_s

		assert_equal "201", response.code.to_s

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		u = User.find(@u.id.to_s)
		assert_equal 1, u.organization_members.size

    end


    test " -- user requests to join organization -- " do 

    	o = Organization.new
    	o.name = "hello"
    	o.phone_number = "1234545"
    	o.address = "jhome"
    	o.role = "lab"
    	o.verifiers = 2
    	o.description = "dog"
    	o.created_by_user_id = @u.id.to_s
    	o.created_by_user = @u
        o.assign_id_from_name
    	o.save

    	#puts o.errors.full_messages.to_s
    	assert_equal true, o.errors.full_messages.blank?

    	#puts "the headers are:"
    	#puts @pathan_headers.to_s
    	#puts user.attributes.to_s

    	put profile_path(:id => @pathan.id.to_s, resource: "users"), params: {user: { organization_members: [{organization_id: "hello", employee_role_id: "Technician"}]}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @pathan_headers


    	#put profile_path(:id => @u.id.to_s, resource: "users"), params: {user: {organization_member_organization_id: "hello", organization_member_employee_role_id: "Technician"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers



    	assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

    	## get the user organization members
    	u = User.find(@pathan.id.to_s)
        ## so why has it not added these to the organization members

    	assert_equal 1, u.organization_members.size

    end

    test " -- correctly shows the membership status of the user in the organization -- " do 

        o = Organization.new
        o.name = "hello"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @u.id.to_s
        o.created_by_user = @u
        o.assign_id_from_name
        o.save

        assert_equal true, o.errors.full_messages.blank?

        put profile_path(:id => @pathan.id.to_s, resource: "users"), params: {user: { organization_members: [{organization_id: "hello", employee_role_id: "Technician"}]}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @pathan_headers


        assert_equal "204", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        u = User.find(@pathan.id.to_s)

        assert_equal 1, u.organization_members.size
        assert_equal Organization::USER_PENDING_VERIFICATION, u.organization_members[0].membership_status

    end 

    test " -- accepts user in organization, and correctly shows its membership status as accepted -- " do 

    	o = Organization.new
        o.name = "hello"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @u.id.to_s
        o.created_by_user = @u
        o.assign_id_from_name
        o.save

        assert_equal true, o.errors.full_messages.blank?
            	   
        pathan = User.find(@pathan.id.to_s)
        pathan.organization_members.push(OrganizationMember.new(:organization_id => "hello", :employee_role_id => "Technician"))
        pathan.save
        assert_equal true, pathan.errors.full_messages.blank?

        puts "the organization user ids are:"
        puts o.user_ids.to_s

        o.user_ids.push(pathan.id.to_s)

        puts "-------- the organization attributes"
        puts o.attributes.to_s

        put organization_path(o.id.to_s), params: {organization: {name: o.name, description: o.description, phone_number: o.phone_number, address: o.address, role: o.role, user_ids: o.user_ids}, :api_key => @ap_key, :current_app_id => "testappid"  }.to_json, headers: @headers

        assert_equal response.code.to_s, "204"

        pathan = User.find(pathan.id.to_s)
        assert_equal Organization::USER_VERIFIED, pathan.organization_members[0].membership_status        
    end

    test " -- adds a parent organization -- " do 

        o = Organization.new
        o.name = "hello"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @u.id.to_s
        o.created_by_user = @u
        o.assign_id_from_name
        o.save

        post organizations_path, params: {organization: {name: "child organization", description: "a good lab", address: "a new place", role: "lab", verifiers: 2, phone_number: "9561137096", parent_id: o.id.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @pathan_headers

        puts response.body.to_s

        assert_equal "201", response.code.to_s

        ## should add this to the children of the parent.
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        o = Organization.find(o.id.to_s)
        assert_equal o.children.size, 1

    end

=end
    ## still header, and location shit is left.
    ## tomorrow.
    ## so next week will be for report, test, order, rates and payments.
=begin
    test " -- cascades the impact to grandparents of the parent organization -- " do 

        ## so lets create one organization

        ## make a parent.

        o = Organization.new
        o.name = "grandpa"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @u.id.to_s
        o.created_by_user = @u
        o.assign_id_from_name
        o.save


        o2 = Organization.new
        o2.name = "father"
        o2.phone_number = "1234545"
        o2.address = "jhome"
        o2.role = "lab"
        o2.verifiers = 2
        o2.description = "dog"
        o2.created_by_user_id = @u.id.to_s
        o2.created_by_user = @u
        o2.assign_id_from_name
        o2.parent_id = o.id.to_s
        o2.save

        post organizations_path, params: {organization: {name: "child", description: "a good lab", address: "a new place", role: "lab", verifiers: 2, phone_number: "9561137096", parent_id: o2.id.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @pathan_headers

        puts response.body.to_s

        assert_equal "201", response.code.to_s

        ## should add this to the children of the parent.
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Organization.find(o.id.to_s)
        assert_equal o.children.size, 2

        o2 = Organization.find(o2.id.to_s)
        assert_equal o2.children.size, 1   

    end
=end
=begin
    test " -- child organization records are accessible, and editable -- " do 

        ## now first make an organization by atif.
        o = Organization.new
        o.name = "organization one"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @atif.id.to_s
        o.created_by_user = @atif
        o.assign_id_from_name
        o.save
        puts o.errors.full_messages.to_s
        assert_equal true, o.errors.full_messages.blank?
            
        ## important to do this to set hte organizatoin.
        @atif = User.find(@atif.id.to_s)

        item_type_two = Inventory::ItemType.new
        item_type_two.created_by_user = @atif
        item_type_two.created_by_user_id = @atif.id.to_s
        item_type_two.name = "second item type"
        item_type_two.barcode_required = true
        item_type_two.virtual_units = 10
        item_type_two.assign_id_from_name
        item_type_two.save
        puts item_type_two.errors.full_messages.to_s
        assert_equal true, item_type_two.errors.full_messages.blank?
        

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        
        @pathan = User.find(@pathan.id.to_s)
        @pathan.organization_members.push(OrganizationMember.new(organization_id: o.id.to_s, employee_role_id: "Technician"))
        @pathan.skip_authentication_token_regeneration = true
        @pathan.save
        assert_equal true, @pathan.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Organization.find(o.id.to_s)
        o.user_ids.push(@pathan.id.to_s)
        o.created_by_user_id = @atif.id.to_s
        o.created_by_user = @atif
        o.save
        puts o.errors.full_messages.to_s
        assert_equal true, o.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        ## okay so the organization setting is either not working or whatever its not working out.

        get inventory_item_type_path(item_type_two.id.to_s), params: {current_app_id: "testappid", api_key: @ap_key}, headers: @pathan_headers

        assert_equal "200", response.code.to_s

        ## so this works.
        ## now we want to see what happens if it is a 
        ## non-related organization.  
    end
=end
    
=begin
    test " -- can select a different organization using a header -- " do 

        ## now first make an organization by atif.
        o = Organization.new
        o.name = "organization one"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @atif.id.to_s
        o.created_by_user = @atif
        ## pathan is part of both organizations.
        o.assign_id_from_name
        o.save
        puts o.errors.full_messages.to_s
        assert_equal true, o.errors.full_messages.blank?
            
        ## important to do this to set hte organizatoin.
        @atif = User.find(@atif.id.to_s)

        o2 = Organization.new
        o2.name = "organization two"
        o2.phone_number = "1234545"
        o2.address = "jhome"
        o2.role = "lab"
        o2.verifiers = 2
        o2.description = "dog"
        o2.created_by_user_id = @u.id.to_s
        o2.created_by_user = @u
        ## pathan is part of both organizations.
        o2.assign_id_from_name
        o2.save
        puts o2.errors.full_messages.to_s
        assert_equal true, o2.errors.full_messages.blank?
            
        ## important to do this to set hte organizatoin.
        @u = User.find(@u.id.to_s)
        item_type_two = Inventory::ItemType.new
        item_type_two.created_by_user = @u
        item_type_two.created_by_user_id = @u.id.to_s
        item_type_two.name = "second item type"
        item_type_two.barcode_required = true
        item_type_two.virtual_units = 10
        item_type_two.assign_id_from_name
        item_type_two.save
        puts item_type_two.errors.full_messages.to_s
        assert_equal true, item_type_two.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        
        @pathan = User.find(@pathan.id.to_s)
        @pathan.organization_members.push(OrganizationMember.new(organization_id: o.id.to_s, employee_role_id: "Technician"))
        @pathan.organization_members.push(OrganizationMember.new(organization_id: o2.id.to_s, employee_role_id: "Technician"))
        @pathan.skip_authentication_token_regeneration = true
        @pathan.save
        assert_equal true, @pathan.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Organization.find(o.id.to_s)
        o.user_ids.push(@pathan.id.to_s)
        o.created_by_user_id = @atif.id.to_s
        o.created_by_user = @atif
        o.save
        puts o.errors.full_messages.to_s
        assert_equal true, o.errors.full_messages.blank?

        o2 = Organization.find(o2.id.to_s)
        o2.user_ids.push(@pathan.id.to_s)
        o2.created_by_user_id = @u.id.to_s
        o2.created_by_user = @u
        o2.save
        puts o2.errors.full_messages.to_s
        assert_equal true, o2.errors.full_messages.blank?

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        ## now its a part of two organizations.
        ## find the user and check the membership status of both first.
        ## then see if you can use the header to choose.
        @pathan = User.find(@pathan.id.to_s)

        assert_equal 2,@pathan.organization_members.size
       
        @pathan.organization_members.each do |om|
            assert_equal Organization::USER_VERIFIED, om.membership_status
        end

        ## now comes the point of organization decision.
        ## lets send in the orgnaiztion header.
        ## make him choose the second organization type.
        get inventory_item_type_path(item_type_two.id.to_s), params: {current_app_id: "testappid", api_key: @ap_key}, headers: @pathan_headers.merge({Concerns::OrganizationConcern::ORGANIZATION_ID_HEADER => o2.id.to_s})

        assert_equal response.code.to_s, "200"
    end
=end
=begin
    test " -- removes a parent organization -- " do 
            
        o = Organization.new
        o.name = "grandpa"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @u.id.to_s
        o.created_by_user = @u
        o.assign_id_from_name
        o.save
        assert_equal true, o.errors.full_messages.blank?

        ## organization 2.
        o2 = Organization.new
        o2.name = "father"
        o2.phone_number = "1234545"
        o2.address = "jhome"
        o2.role = "lab"
        o2.verifiers = 2
        o2.description = "dog"
        o2.created_by_user_id = @u.id.to_s
        o2.created_by_user = @u
        o2.assign_id_from_name
        o2.parent_id = o.id.to_s
        o2.save
        assert_equal true, o2.errors.full_messages.blank?

        ## now add a child.
        o3 = Organization.new
        o3.name = "child"
        o3.phone_number = "1234545"
        o3.address = "jhome"
        o3.role = "lab"
        o3.verifiers = 2
        o3.description = "dog"
        o3.created_by_user_id = @u.id.to_s
        o3.created_by_user = @u
        o3.assign_id_from_name
        o3.parent_id = o2.id.to_s
        o3.save
        assert_equal true, o3.errors.full_messages.blank?
        ## now remove the parent id of organization two.
        o2 = Organization.find(o2.id.to_s)
        ## now remove it and see what happens.
        ## then move to add the location.
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        puts "==============================================#!!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ doing the update action ))))))))))))))))))))))))))))"

        put organization_path(o2.id.to_s), params: {organization: {name: o2.name, description: o2.description, phone_number: o2.phone_number, address: o2.address, role: o2.role, user_ids: o2.user_ids, parent_id: nil}, :api_key => @ap_key, :current_app_id => "testappid"  }.to_json, headers: @headers

        ## i have knocked off the parent.
        ## so the parent should have no children.
        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        o = Organization.find(o.id.to_s)
        puts "============================================="
        puts "the new children are--------------------"
        puts o.children.to_s
        assert_equal true, o.children.blank?

    end
=end
    
=begin
    test " -- searches in the child organizations records also  -- " do 

    end
=end
    
=begin
    test " -- creates a location with the organization -- " do 

        post organizations_path, params: {organization: {name: "first item type", description: "a good lab", address: "a new place", role: "lab", verifiers: 2, phone_number: "9561137096", latitude: 22.23, longitude: 22, address: "hello world"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

        puts "this is the response body -------------->"
        puts response.body.to_s
        
        assert_equal "201", response.code.to_s

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

        search_request = Geo::Location.search({
            query: {
                term: {
                    model_id: "first item type"
                }
            }
        })

        assert_equal 1, search_request.response.hits.hits.size

    end    
=end
    
    test " -- get all organizations -- " do 

        o = Organization.new
        o.name = "grandpa"
        o.phone_number = "1234545"
        o.address = "jhome"
        o.role = "lab"
        o.verifiers = 2
        o.description = "dog"
        o.created_by_user_id = @u.id.to_s
        o.created_by_user = @u
        o.assign_id_from_name
        o.save
        assert_equal true, o.errors.full_messages.blank?

        ## so what is the current users organizatio.

        Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
        ##get organizations_path, 
        get organizations_path, params: {current_app_id: "testappid", api_key: @ap_key}, headers: @headers

        puts response.body.to_s

    end

end