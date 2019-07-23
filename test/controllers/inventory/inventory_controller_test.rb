require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest

	setup do 

		Organization.create_index! force: true
		#NormalRange.create_index! force: true
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

		@headers_kondhwa = { "CONTENT_TYPE" => "application/json" , "ACCEPT" => "application/json", "X-User-Token" => @atif.authentication_token, "X-User-Es" => @atif.client_authentication["testappid"], "X-User-Aid" => "testappid"}
		
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

=begin
	test " -- creates item type -- " do 

		post inventory_item_types_path, params: {item_type: {name: "first item type", barcode_required: "yes", virtual_units: 10 }, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal "201", response.code.to_s

	end
=end

=begin
	test " -- creates item group with item types, and quantities -- " do 

		## we have to be able to create an item type
		## without fucking up.
		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.

		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save
		## now save them both into the shit.

		post inventory_item_groups_path, params: {item_group: {item_definitions: [
				{
					item_type_id: "first item type",
					quantity: 2,
					expiry_date: "2015-01-01"	
				},
				{
					item_type_id: "second item type",
					quantity: 5,
					expiry_date: "2018-01-01"
				}
		], name: "Item Group", group_type: "kit"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers_kondhwa

		assert_equal "201", response.code

	end
=end

=begin
	test " -- orders an item group -- " do 
	
		## we have to be able to create an item type
		## without fucking up.
		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		## create a transaction.
		#tr = Inventory::Transaction.new
		#tr.supplier_item_group_id = item_group.id.to_s
		#tr.supplier_id = item_group.supplier_id
		#tr.created_by_user = @u
		#tr.assign_id_from_name
		#tr.save

		post inventory_transactions_path, params: {transaction: {supplier_item_group_id: item_group.id.to_s, supplier_id: item_group.supplier_id}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		puts "the response body is:"
		puts response.body.to_s
		puts "the response code is: #{response.code.to_s}"

	end
=end

=begin
	test " -- receives an item group order, and creates local item groups, equal to the quantity received. -- " do 

		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		tr.assign_id_from_name
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers



		puts "the response code is:"
		puts response.code.to_s

		puts "the response body is:"
		puts response.body.to_s

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		search_results = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group.id.to_s
				}
			}
		})

		assert_equal 1, search_results.response.hits.hits.size
	end
=end
=begin
	test " -- receives an item group order, and creates local item groups, equal to the quantity received, the local item group is owned by the organization that ordered the item group -- " do 

		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		tr.assign_id_from_name
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers


		puts "the response code is:"
		puts response.code.to_s

		puts "the response body is:"
		puts response.body.to_s

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		search_query = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group.id.to_s
				}
			}
		})

		puts "the search result response hits are --------------------- "
		puts search_query.response.hits.hits.to_s

		local_item_group = Inventory::ItemGroup.new(search_query.response.hits.hits.first["_source"])
		local_item_group.id = search_query.response.hits.hits.first["_id"]

		#puts "the local item group attributes are:"
		#puts local_item_group.attributes.to_s

		#puts "the ordering users organization id is:"
		#puts @u.organization.id.to_s

		#puts "the owner ids are:"
		#puts local_item_group.currently_held_by_organization

		## so the local item group is not yet settled.

		assert_equal local_item_group.currently_held_by_organization, @u.organization.id.to_s
		#assert_equal local_item_group.owner_ids.include? @u.organization.id.to_s, true
		#assert_equal local_item_group.currently_held_by_organization, @u.organization.id.to_s 
	end
=end

=begin
	test " -- creates item belonging local item group -- " do 
			
		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		tr.assign_id_from_name
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.quantity_received = 2
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		search_results = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group.id.to_s
				}
			}
		})

		assert_equal 1, search_results.response.hits.hits.size
		local_item_group = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
		local_item_group.run_callbacks(:find)

		## now we make an item.
		post inventory_items_path, params: {item: {transaction_id: tr.id.to_s, supplier_item_group_id: item_group.id.to_s, local_item_group_id: local_item_group, item_type_id: item_type_two.id.to_s, barcode: "123445", expiry_date: "2015-05-05"}}

		assert_equal "201", response.code.to_s


	end
=end
=begin
	test " -- transfers single time between members of different organizations -- " do 
			
		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		tr.assign_id_from_name
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.quantity_received = 2
		tr.created_by_user = @u
		tr.run_callbacks(:find)
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		search_results = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group.id.to_s
				}
			}
		})

		assert_equal 1, search_results.response.hits.hits.size
		local_item_group = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
		local_item_group.run_callbacks(:find)


		item = Inventory::Item.new
		item.transaction_id = tr.id.to_s
		item.supplier_item_group_id = item_group.id.to_s
		item.local_item_group_id = local_item_group.to_s
		item.item_type_id = item_type_two.id.to_s
		item.barcode = "1234556"
		item.expiry_date = "2015-05-05"
		item.created_by_user = @u
		item.assign_id_from_name
		item.save
		puts "the item save errors are----------------------"
		puts item.errors.full_messages
		assert_equal true, item.errors.full_messages.blank?
		
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		post inventory_item_transfers_path, params: {item_transfer: {to_user_id: @u.id.to_s, reason: "Just for the heck of it.", name: "new item transfer", model_id: item.id.to_s, model_class: item.class.name.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal response.code.to_s, "201"

		## get the item.
		## check its organization ids.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		item = Inventory::Item.find(item.id.to_s)
		assert_equal 2, item.owner_ids.size
		assert_equal @u.organization.id.to_s, item.currently_held_by_organization

	end
=end
=begin
	test " -- transfers item between members of different organizations -- " do 

		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		tr.assign_id_from_name
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.quantity_received = 2
		tr.created_by_user = @u
		tr.run_callbacks(:find)
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		search_results = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group.id.to_s
				}
			}
		})

		assert_equal 1, search_results.response.hits.hits.size
		local_item_group = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
		local_item_group.run_callbacks(:find)


		item = Inventory::Item.new
		item.transaction_id = tr.id.to_s
		item.supplier_item_group_id = item_group.id.to_s
		item.local_item_group_id = local_item_group.to_s
		item.item_type_id = item_type_two.id.to_s
		item.barcode = "1234556"
		item.expiry_date = "2015-05-05"
		item.created_by_user = @u
		item.assign_id_from_name
		item.save
		puts "the item save errors are----------------------"
		puts item.errors.full_messages
		assert_equal true, item.errors.full_messages.blank?
		
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		## its like we are giving this to atif.
		post inventory_item_transfers_path, params: {item_transfer: {to_user_id: @atif.id.to_s, reason: "Just for the heck of it.", name: "new item transfer", model_id: item.id.to_s, model_class: item.class.name.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal response.code.to_s, "201"

		## get the item.
		## check its organization ids.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		item = Inventory::Item.find(item.id.to_s)
		assert_equal 3, item.owner_ids.size
		assert_equal @atif.organization.id.to_s, item.currently_held_by_organization

	end
=end

=begin
	test " transfers item group and all its component items to the other organization " do 

		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.assign_id_from_name
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.assign_id_from_name
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = @atif
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2015-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2018-01-01"
			}
		]
		item_group.assign_id_from_name
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		tr.assign_id_from_name
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		## the local item group should be owned by the local user.
		## that's where we are going wrong.

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.quantity_received = 2
		tr.created_by_user = @u
		tr.run_callbacks(:find)
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		search_results = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group.id.to_s
				}
			}
		})

		assert_equal 1, search_results.response.hits.hits.size
		local_item_group = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
		local_item_group.run_callbacks(:find)

		item = Inventory::Item.new
		item.transaction_id = tr.id.to_s
		item.supplier_item_group_id = item_group.id.to_s
		item.local_item_group_id = local_item_group.to_s
		item.item_type_id = item_type_two.id.to_s
		item.barcode = "1234556"
		item.expiry_date = "2015-05-05"
		item.created_by_user = @u
		item.assign_id_from_name
		item.save
		puts "the item save errors are----------------------"
		puts item.errors.full_messages
		assert_equal true, item.errors.full_messages.blank?

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		## its like we are giving this to atif.
		post inventory_item_transfers_path, params: {item_transfer: {to_user_id: @atif.id.to_s, reason: "Transferring local item group.", name: "new item group transfer", model_id: local_item_group.id.to_s, model_class: local_item_group.class.name.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		puts "-------------- this is the response body -------------- "
		puts response.body.to_s
		assert_equal response.code.to_s, "201"

		## get the item.
		## check its organization ids.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"

		## so this done.
		## now i want to see what all is returned with profile.
		## in the user.
		## what to override to return organization details. 
		item = Inventory::Item.find(item.id.to_s)
		assert_equal 3, item.owner_ids.size
		assert_equal @atif.organization.id.to_s, item.currently_held_by_organization

	end
=end
	
=begin
	test " transfers transaction and all its components to another organization -- " do 

	end
=end
		
=begin
	test " -- transferring items between local item groups, subtracts it from the existing item group and transfers it to the new item group -- " do 

	end
=end	
	
=begin
	test " -- allows lab/hospital/doctor to create local item groups with new item types, and then populate them with items -- " do 

	end
=end	
	
	## when a report is copied, the equipment is not copied
	## that report cannot be used till the equipment is chosen for it, and successfully copied over.
	## equipment name
	## model number
	## serial number(not to be copied)
	## id is organization/class/then whatever.
	## 
	## okay so the next step is going to be get on with 
	## what exactly?
	## move to normal range -> test -> report
	## how to copy over when a new lab is created
	## how to allow them to modify
	## they should be able to add new tests and reports
	## and also status 
	## we also need equipment -> and all its bullshit.
	## after that is done, i can move to order and patient.
	## and the integration of status with inventory items.
	## so basically
	## status -> item requirement -> minute -> report -> test -> normal range -> order
	## and last of all patient.
	## so let's get the show on the road.
	## so start with normal range.
	## we have to refactor to add it to the test
	## so how to copy the tests
	## if i change one normal range?
	## change the range -> owned by the current organization?
	## otherwise use the one from the default organization.
	## so we can create normal range.
	## lets start with that.
	## you will have to put the versioned concern ui first.
	## does it need a machine id?
	## why not just finish equipment and related issues today
	## it has a maintainance schedule
	## it has certificates, 
	## it has an array of certifications (like IQ, OQ, PQ, Installation Certicicate)
	## it has a maintainance log -> 
	## it has a breakdown log ->
	## and those are basically status routines.
	## but i can make an equipment model and controller and some views quickly, to show some progress for the day.
	## it should show which tests are done on it, by that organization, etc.
	## it will be copied over to the organization.
	## so will the reports on an as needed basis.


end