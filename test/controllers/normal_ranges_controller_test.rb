require "test_helper"

class NormalRangesControllerTest < ActionDispatch::IntegrationTest

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


		@organization = Organization.new(name: "Pathofast diagnostis", address: "Manisha Terrace, 2nd floor", phone_number: "020 49304930", description: "A good lab", verifiers: 2, user_ids: [@u2.id.to_s], role_ids: ["Pathologist","Technician"])
		## @u1 will be a 
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
		#puts @u2.organization_id.to_s
		#exit(1)

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		@u2 = User.find(@u2.id.to_s)
		@u = User.find(@u.id.to_s)
		#puts @u2.organization.to_s
		#exit(1)
		#@u2.run_callbacks(:find)
	end

=begin
	## JSON.
	test "it creates the first version of the document on create" do
		post(normal_ranges_path ,params: {normal_range: {name: "hello"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers)
		puts response.body.to_s
		normal_range = NormalRange.new(JSON.parse(response.body)["normal_range"])
		assert_equal 1, normal_range.versions.size
	end
=end

=begin
	test "after creating one version, a subsequent update will not work for any parameter other than accepted or rejected user ids " do 

		nr = NormalRange.new

		nr.created_by_user = @u
		
		nr.name = "hello"
		nr.verified_by_user_ids = [@u.id.to_s]
		
		v = Version.new({attributes_string: JSON.generate({name: "hello", verified_by_user_ids: [@u.id.to_s], rejected_by_user_ids: []})})
		
		v.assign_control_doc_number
		
		nr.versions << v
		
		nr.save

		nr = NormalRange.find(nr.id.to_s)
		puts nr.attributes.to_s
		#exit(1)
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		put normal_range_path(nr.id.to_s), params: {normal_range: {name: "goodbye", verified_by_user_ids: nr.verified_by_user_ids}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		puts "the "
		assert_equal response.code.to_s, "204" 
		#normal_range = JSON.parse(response.body["normal_range"])
		#puts response.code.to_s
		nr = NormalRange.find(nr.id.to_s)
		assert_equal nr.versions.size, 1
		#puts nr.versions.to_s
		
	end
=end

=begin
	test "after creating one version, subsequent update can verify it by another user, and the changes get applied to the master object. " do 

		nr = NormalRange.new

		nr.created_by_user = @u
		
		nr.name = "hello"
		nr.verified_by_user_ids = [@u.id.to_s]
		
		v = Version.new({attributes_string: JSON.generate({name: "hello", verified_by_user_ids: [@u.id.to_s], rejected_by_user_ids: []})})
		
		v.assign_control_doc_number
		
		nr.versions << v
		
		nr.save

		nr = NormalRange.find(nr.id.to_s)
		puts nr.attributes.to_s
		#exit(1)
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		put normal_range_path(nr.id.to_s), params: {normal_range: {verified_by_user_ids: nr.verified_by_user_ids.push(@u2.id.to_s)}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal response.code.to_s, "204" 
		#normal_range = JSON.parse(response.body["normal_range"])
		#puts response.code.to_s
		nr = NormalRange.find(nr.id.to_s)
		assert_equal nr.versions.size, 2
		assert_equal nr.active, 1

	end
=end
=begin
	test "after creating one version, subsequent update can reject it and this causes a rollback to created version parameters" do 

		nr = NormalRange.new

		nr.created_by_user = @u
		
		nr.name = "hello"
		nr.verified_by_user_ids = [@u.id.to_s]
		
		v = Version.new({attributes_string: JSON.generate({name: "hello", verified_by_user_ids: [@u.id.to_s], rejected_by_user_ids: []})})
		
		v.assign_control_doc_number
		
		nr.versions << v
		
		nr.save

		nr = NormalRange.find(nr.id.to_s)
		puts nr.attributes.to_s
		#exit(1)
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		put normal_range_path(nr.id.to_s), params: {normal_range: {rejected_by_user_ids: [@u2.id.to_s], verified_by_user_ids: nr.verified_by_user_ids}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal response.code.to_s, "204" 
		#normal_range = JSON.parse(response.body["normal_range"])
		#puts response.code.to_s
		nr = NormalRange.find(nr.id.to_s)
		assert_equal nr.versions.size, 2
		assert_equal nr.active, 0		

	end
=end

	test "-- create, then update as verified, then update some other parameters, then reject those changes, goes back to the verified version --  " do 

		nr = NormalRange.new

		nr.created_by_user = @u
		
		nr.name = "hello"
		nr.verified_by_user_ids = [@u.id.to_s]
		
		v = Version.new({attributes_string: JSON.generate({name: "hello", verified_by_user_ids: [@u.id.to_s], rejected_by_user_ids: []})})
		
		v.assign_control_doc_number
		
		nr.versions << v
		
		nr.save

		
		#exit(1)
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		nr = NormalRange.find(nr.id.to_s)
		puts nr.attributes.to_s

		v = Version.new({attributes_string: JSON.generate({verified_by_user_ids: [@u.id.to_s,@u2.id.to_s], rejected_by_user_ids: []})})
		
		v.assign_control_doc_number
		
		nr.versions << v
		nr.created_by_user = @u2
		nr.save

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		## assert two versions and activr.
		assert_equal 2, nr.versions.size
		assert_equal 1, nr.active


		v = Version.new({attributes_string: JSON.generate({name:"goodbye", verified_by_user_ids: [@u.id.to_s]})})
		
		v.assign_control_doc_number
		
		nr.versions << v
		nr.created_by_user = @u
		nr.save

		## now make some more changes.
		put normal_range_path(nr.id.to_s), params: {normal_range: {rejected_by_user_ids: [@u2.id.to_s]}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers
		assert_equal response.code.to_s, "204" 

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
		#what will be the condition now.
		#there will be 1 verified by user_id.
		#now if we reject, it should go back and apply the earlier goodbye to the attributes.
		#anyways this will not be on the attributes.
		#normal_range = JSON.parse(response.body["normal_range"])
		#puts response.code.to_s
		nr = NormalRange.find(nr.id.to_s)
		assert_equal 4, nr.versions.size
		assert_equal nr.name, "hello"
	end	

	# we create an item type.
	# What apis so to give these guys now?
	# create organization 
	# upload image
	# set roles
	# accept and reject employees
	# all these api's have to be documented.
	# next would have been inventory.
	# actually.
	# and a barcode scanner api.
	# they have to be able to choose their role as well.
	# what would make sense is for the inventory api to also be completed, so that they can work on that one as well.
	# and i finish the tests on the versioned concern.
	# log the download errors.
	# and put a while loop to save time on poller creation.
	# check poller saturation.

=begin

	test " -- verifier, or rejecter cannot be anything other than current user -- " do 


	end


	test " -- tampering with untamperable params, will not allow verification or rejection -- " do 


	end

	test " -- same user cannot accept or verify the version -- " do 


	end
=end

## good so by day end ill finish these things.
## then we move forward.
## consumption can be through status 

end