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
		@c = Auth::Client.new(:resource_id => @u.id, :api_key => "test", :app_ids => ["testappid"])
        @c.redirect_urls = ["http://www.google.com"]
        @c.versioned_create
        @u.client_authentication["testappid"] = "test_es_token"
        @u.save
        puts @u.errors.full_messages.to_s
        puts "----------------------------"
        user = User.find(@u.id.to_s)
        #puts @u.authentication_token
        #puts @u.es.to_s
        #exit(1)
        @ap_key = @c.api_key
		@organization = Organization.new(name: "Pathofast diagnostis", address: "Manisha Terrace, 2nd floor", phone_number: "020 49304930", description: "A good lab", verifiers: 2)
		@organization.created_by_user = @u
		@organization.save
		#puts "organization save errors"
		#puts organization.errors.full_messages.to_s

		@headers = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @u.authentication_token, "X-User-Es" => @u.client_authentication["testappid"], "X-User-Aid" => "testappid"}
		puts "headers are:"
		puts JSON.pretty_generate(@headers)
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
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-normal-ranges"

		put normal_range_path(nr.id.to_s), params: {normal_range: {name: "goodbye", verified_by_user_ids: nr.verified_by_user_ids}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		puts "the "
		assert_equal response.code.to_s, "204" 
		#normal_range = JSON.parse(response.body["normal_range"])
		#puts response.code.to_s
		nr = NormalRange.find(nr.id.to_s)
		assert_equal nr.versions.size, 1
		#puts nr.versions.to_s
		
	end


=begin
	test "after creating one version, subsequent update can verify it, and the changes get applied to the master object. " do 

	end

	test "after creating one version, subsequent update can reject it and this causes a rollback to created version parameters" do 


	end


	test "-- create, then update as verified, then update some other parameters, then reject those changes, goes back to the verified version --  " do 


	end


	test " -- verifier, or rejecter cannot be anything other than current user -- " do 


	end


	test " -- tampering with untamperable params, will not allow verification or rejection -- " do 


	end

	test " -- same user cannot accept or verify the version -- " do 


	end
=end


end