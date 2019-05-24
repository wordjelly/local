require "test_helper"

class ItemTransfersControllerTest < ActionDispatch::IntegrationTest

	## so i want to do a cross transfer.
	## how do we test that though?
	## 

	setup do 
		Organization.create_index! force: true
		NormalRange.create_index! force: true
		User.delete_all
        Auth::Client.delete_all
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
		
		@pathologist_role = Tag.new(name: "Pathologist",created_by_user: @u, tag_type: Tag::EMPLOYEE_TAG)
		@pathologist_role.save


		@technician_role = Tag.new(name: "Technician", created_by_user: @u, tag_type: Tag::EMPLOYEE_TAG)
		@technician_role.save


		@organization = Organization.new(name: "Pathofast diagnostis", address: "Manisha Terrace, 2nd floor", phone_number: "020 49304930", description: "A good lab", verifiers: 2, user_ids: [@u2.id.to_s], role_ids: ["Pathologist","Technician"], role: Organization::LAB)

		@organization.created_by_user = @u
		@organization.save

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		@headers = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @u.authentication_token, "X-User-Es" => @u.client_authentication["testappid"], "X-User-Aid" => "testappid"}
		
		@u2.organization_id = @organization.id.to_s
		@u2.employee_role_id = "Pathologist"
		puts "it organization id is: #{@u2.organization_id}"
		@u2.save
		puts "--------------------- THESE ARE THE ERROR MESSAGES ---------------- "
		puts @u2.errors.full_messages

		@u2 = User.find(@u2.id.to_s)
		

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		@u2 = User.find(@u2.id.to_s)
		@u = User.find(@u.id.to_s)
	end

end