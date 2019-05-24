require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest

	setup do 

		Organization.create_index! force: true
		NormalRange.create_index! force: true
		Tag.create_index! force: true
		
		## finalize every screen, every api call and every view.
		## get him to do it in two days.
		Inventory::ItemType.create_index! force: true
		Inventory::Item.create_index! force: true
		Inventory::Transaction.create_index! force: true
		Inventory::ItemTransfer.create_index! force: true
		Inventory::Comment.create_index! force: true
		## that's the end of it.


		User.delete_all
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
        @ap_key = @c.api_key

        #########################################################
        ##
        ##
        ## ROLES
        ##
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
        ##########################################################

        @pathan = User.new(email: "pathan@gmail.com", password: "hello111", password_confirmation: "hello111", confirmed_at: Time.now.to_i)
        @pathan.save
        @pathan = User.find(@pathan.id.to_s)
        @pathan.confirm
        @pathan.save
        @pathan.client_authentication["testappid"] = "test_es_token_four"
        @pathan.employee_role_id = "Technician"
        #########################################################
        ##
        ##
        ## ENDS.
        ##
        ##
        #########################################################
		@organization = Organization.new(name: "Pathofast diagnostis", address: "Manisha Terrace, 2nd floor", phone_number: "020 49304930", description: "A good lab", verifiers: 2, user_ids: [@u2.id.to_s], role_ids: ["Pathologist","Technician"], role: Organization::LAB)
		@organization.created_by_user = @u
		@organization.save

		@organization_kondhwa = Organization.new(name: "Kondhwa Diagnostic Center", address: "Near KEM hospital, Camp", phone_number: "020 44232211", description: "a good lab", verifiers: 2, user_ids: [@pathan.id.to_s], role_ids: ["Pathologist","Technician"], role: Organization::LAB)
		@organization_kondhwa.created_by_user = @atif
		@organization_kondhwa.save

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		@headers = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @u.authentication_token, "X-User-Es" => @u.client_authentication["testappid"], "X-User-Aid" => "testappid"}
		
		@u2.organization_id = @organization.id.to_s
		@u2.employee_role_id = "Pathologist"
		#puts "it organization id is: #{@u2.organization_id}"
		@u2.save
		#puts "--------------------- THESE ARE THE ERROR MESSAGES ---------------- "
		#puts @u2.errors.full_messages

		@u2 = User.find(@u2.id.to_s)
		

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		@u2 = User.find(@u2.id.to_s)
		@u = User.find(@u.id.to_s)
		@atif = User.find(@atif.id.to_s)
		@pathan = User.find(@pathan.id.to_s)

	end


	test " -- creates item type -- " do 

		post inventory_item_types_path, params: {item_type: {name: "first item type", barcode_required: "yes", virtual_units: 10, }, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal "201", response.code.to_s

	end

=begin
	it " -- creates item group with item types, and quantities -- " do 

	end

	it " -- orders an item group -- " do 

	end


	it " -- receives an item group order -- " do 

	end
=end

end