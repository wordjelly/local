require "test_helper"
require 'helpers/test_helper'


class InventoryControllerTest < ActionDispatch::IntegrationTest

	include TestHelper

	setup do 
		_setup({
			"bhargav_raut" => {
				"use_transaction_inventory" => true
			}
		})
	end


	## first fix this spec.
	## then proceed.
	test " -- creates item type -- " do 

		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

		post inventory_item_types_path, params: {item_type: {name: "first item type", barcode_required: "yes", virtual_units: 10 }, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

		assert_equal "201", response.code.to_s

	end

	test " -- creates item group with item types, and quantities -- " do 

		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first
		## we have to be able to create an item type
		## without fucking up.
		item_type = Inventory::ItemType.new
		item_type.created_by_user = plus_lab_employee
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type.save
		unless item_type.errors.full_messages.blank?
			puts "errors saving item type"
			exit(1)
		end
		## now create another item type.

		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = plus_lab_employee
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type_two.save
		unless item_type_two.errors.full_messages.blank?
			puts "errors saving item type two"
			exit(1)
		end
		## now save them both into the shit.

		post inventory_item_groups_path, params: {item_group: {item_definitions: [
				{
					item_type_id: "first item type",
					quantity: 2,
					expiry_date: "2025-01-01"	
				},
				{
					item_type_id: "second item type",
					quantity: 5,
					expiry_date: "2028-01-01"
				}
		], name: "Item Group", group_type: "kit"}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

		assert_equal "201", response.code

	end

	test " -- orders an item group -- " do 
	
		## we have to be able to create an item type
		## without fucking up.
		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

		item_type = Inventory::ItemType.new
		item_type.created_by_user = plus_lab_employee
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = plus_lab_employee
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = plus_lab_employee
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2028-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		## create a transaction.
		#tr = Inventory::Transaction.new
		#tr.supplier_item_group_id = item_group.id.to_s
		#tr.supplier_id = item_group.supplier_id
		#tr.created_by_user = @u
		
		#tr.save

		post inventory_transactions_path, params: {transaction: {supplier_item_group_id: item_group.id.to_s, supplier_id: item_group.supplier_id}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)

		puts "the response body is:"
		puts response.body.to_s
		puts "the response code is: #{response.code.to_s}"

	end

	test " -- receives an item group order, and creates local item groups, equal to the quantity received. -- " do 

		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

		item_type = Inventory::ItemType.new
		item_type.created_by_user = plus_lab_employee
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.save
		unless item_type.errors.full_messages.blank?
			puts "errors saving the item"
			exit(1)
		end

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = plus_lab_employee
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10		
		item_type_two.save
		unless item_type_two.errors.full_messages.blank?
			puts "errors saving the item type two"
			exit(1)
		end

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = plus_lab_employee
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2028-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = plus_lab_employee
		tr.created_by_user_id = plus_lab_employee.id.to_s
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,plus_lab_employee)



		puts "the response code is:"
		puts response.code.to_s

		puts "the response body is:"
		puts response.body.to_s

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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

	test " -- receives an item group order, and creates local item groups, equal to the quantity received, the local item group is owned by the organization that ordered the item group -- " do 

		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

		pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first



		item_type = Inventory::ItemType.new
		item_type.created_by_user = plus_lab_employee
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = plus_lab_employee
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = plus_lab_employee
		item_group.created_by_user_id = plus_lab_employee.id.to_s
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2028-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = pathofast_user
		tr.created_by_user_id = pathofast_user.id.to_s
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)


		puts "the response code is:"
		puts response.code.to_s

		puts "the response body is:"
		puts response.body.to_s

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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


		assert_equal local_item_group.currently_held_by_organization, pathofast_user.organization.id.to_s
		#assert_equal local_item_group.owner_ids.include? @u.organization.id.to_s, true
		#assert_equal local_item_group.currently_held_by_organization, @u.organization.id.to_s 
	end

	test " -- creates item belonging local item group -- " do 
				
		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first

		pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first


		item_type = Inventory::ItemType.new
		item_type.created_by_user = plus_lab_employee
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = plus_lab_employee
		item_type_two.created_by_user_id = plus_lab_employee.id.to_s
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = plus_lab_employee
		item_group.created_by_user_id = plus_lab_employee.id.to_s
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2028-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = pathofast_user
		tr.created_by_user_id = pathofast_user.id.to_s
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.run_callbacks(:find)
		tr.quantity_received = 2
		tr.created_by_user = pathofast_user
		tr.created_by_user_id = pathofast_user.id.to_s
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
		post inventory_items_path, params: {item: {transaction_id: tr.id.to_s, supplier_item_group_id: item_group.id.to_s, local_item_group_id: local_item_group, item_type_id: item_type_two.id.to_s, barcode: "123445", expiry_date: "2025-05-05"},:api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "201", response.code.to_s


	end

	test " -- shifts item from one local item group to another" do 


		plus_lab_employee = User.where(:email => "afrin.shaikh@gmail.com").first


		pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first


		item_type = Inventory::ItemType.new
		item_type.created_by_user = plus_lab_employee
		item_type.created_by_user_id = plus_lab_employee.id.to_s
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = plus_lab_employee
		item_type_two.created_by_user_id = plus_lab_employee.id.to_s
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		
		item_type_two.save

		## now save them both into the shit.
		item_group = Inventory::ItemGroup.new
		item_group.created_by_user = plus_lab_employee
		item_group.created_by_user_id = plus_lab_employee.id.to_s
		item_group.name = "TSH"
		item_group.group_type = "kit"			
		item_group.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2028-01-01"
			}
		]

		item_group.save
		assert_equal [], item_group.errors.full_messages

		## item group two with the same item types.
		item_group_two = Inventory::ItemGroup.new
		item_group_two.created_by_user = plus_lab_employee
		item_group_two.created_by_user_id = plus_lab_employee.id.to_s
		item_group_two.name = "TSH Two"
		item_group_two.group_type = "kit"			
		item_group_two.item_definitions = [
			{
				item_type_id: "first item type",
				quantity: 2,
				expiry_date: "2025-01-01"	
			}
		]
		
		item_group_two.save
		assert_equal [], item_group_two.errors.full_messages

		### ORDER AND SAVE THE FIRST ITEM GROUP.
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = pathofast_user
		tr.created_by_user_id = pathofast_user.id.to_s
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		
		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.run_callbacks(:find)
		tr.quantity_received = 2
		tr.created_by_user = pathofast_user
		tr.created_by_user_id = pathofast_user.id.to_s
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		########### ORDER AND SAVE ITEM TWO
		tr2 = Inventory::Transaction.new
		tr2.supplier_item_group_id = item_group_two.id.to_s
		tr2.supplier_id = item_group_two.supplier_id
		tr2.created_by_user = pathofast_user
		tr2.created_by_user_id = pathofast_user.id.to_s
		tr2.save

		puts "these are the create transaction errors."
		puts tr2.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		
		tr2 = Inventory::Transaction.find(tr2.id.to_s)
		tr2.run_callbacks(:find)
		tr2.quantity_received = 2
		tr2.created_by_user = pathofast_user
		tr2.created_by_user_id = pathofast_user.id.to_s
		tr2.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		#######################################################
		## ADD ITEM TO FIRST ITEM GROUP(LOCAL)

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
		item.local_item_group_id = local_item_group.id.to_s
		item.item_type_id = item_type.id.to_s
		item.barcode = "12345"
		item.expiry_date = "2025-05-05"
		item.created_by_user = pathofast_user
		item.created_by_user_id = pathofast_user.id.to_s
		item.save

		assert_equal [], item.errors.full_messages


		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		search_results = Inventory::ItemGroup.search({
			size: 1,
			query: {
				term: {
					cloned_from_item_group_id: item_group_two.id.to_s
				}
			}
		})


		local_item_group_two = Inventory::ItemGroup.new(search_results.response.hits.hits.first)
		local_item_group_two.run_callbacks(:find)

		## now do the transfer item group call.

		put inventory_item_path(item.id.to_s), params: {item: item.attributes.merge({local_item_group_id: local_item_group_two.id.to_s}), :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"
		## now get that item and see its local item group.
		item = Inventory::Item.find(item.id.to_s)
		assert_equal item.local_item_group_id, local_item_group_two.id.to_s
		#{item: {transaction_id: tr.id.to_s, supplier_item_group_id: item_group.id.to_s, local_item_group_id: local_item_group, item_type_id: item_type_two.id.to_s, barcode: "123445", expiry_date: "2025-05-05"},:api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		## now we have to put.


	end

	test " -- does not shift item , if it is part of an order, marked as incomplete -- " do 

		pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		order = build_pathofast_patient_order(nil,nil,pathofast_user)
		order.save


		unless order.errors.full_messages.blank?
			puts "errors saving order THIS ONE------------"
			puts order.errors.full_messages
			exit(1)
		end		

		pathofast_items = Inventory::Item.find_organization_items(pathofast_user.organization.id.to_s,"BD_SST_tube")

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		order.categories.each_with_index {|category,key|
			if pathofast_items[0].categories.include? category.name
				category.items << Inventory::Item.new(barcode: pathofast_items[0].barcode, item_type_id: pathofast_items[0].item_type_id, transaction_id: pathofast_items[0].transaction_id, expiry_date: pathofast_items[0].expiry_date)
			end
		}
		order.created_by_user = pathofast_user
		#order.reports[0].categories[0].items.add(Inventory::Item.new(barocde: pathofast_items[0]))
		order.save
		unless order.errors.full_messages.blank?
			puts "errors saving order"
			puts order.errors.full_messages
			exit(1)
		end		

		order = Business::Order.find(order.id.to_s)

		## now we order another item group.

		## of the same type.
		## as before.
		## and try to add this item to that.
		pathofast_item_groups = Inventory::ItemGroup.find_organization_item_groups(pathofast_user.organization.id.to_s)

		puts "pathofast item groups are:"
		puts pathofast_item_groups.to_s

		newly_cloned_item_group = nil
		pathofast_item_groups.each do |item_group|
			if item_group.cloned_from_item_group_id.blank?
				if item_group.name == "BD SST Tube 5 tubes"
					## we want to make transaction and clone.
					newly_cloned_item_group = order_item_group({:user => pathofast_user, :item_group_id => item_group.id.to_s})

				end
			end
		end

		## now if you try to transfer an item to this.
		## it should not allow it.
		## we basically update that item.
		## so this should not be allowed at all.
		## validate this.
		item = Inventory::Item.find(pathofast_items[0].id.to_s)
		item.run_callbacks(:find)
		item.local_item_group_id = newly_cloned_item_group.id.to_s
		item.created_by_user = pathofast_user
		item.created_by_user_id = pathofast_user.id.to_s
		#item.save
		## i need to look into that.
		#puts item.errors.full_messages.to_s

		put inventory_item_path(item.id.to_s), params: {item: item.attributes.merge({local_item_group_id: newly_cloned_item_group.id.to_s}), :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "404", response.code.to_s

		puts response.body.to_s

	end


	test " -- shifts item if the previous order has been marked as completed -- " do 

		pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		order = build_pathofast_patient_order(nil,nil,pathofast_user)
		order.save


		unless order.errors.full_messages.blank?
			puts "errors saving order THIS ONE------------"
			puts order.errors.full_messages
			exit(1)
		end		

		pathofast_items = Inventory::Item.find_organization_items(pathofast_user.organization.id.to_s,"BD_SST_tube")

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		order.categories.each_with_index {|category,key|
			if pathofast_items[0].categories.include? category.name
				category.items << Inventory::Item.new(barcode: pathofast_items[0].barcode, item_type_id: pathofast_items[0].item_type_id, transaction_id: pathofast_items[0].transaction_id, expiry_date: pathofast_items[0].expiry_date)
			end
		}
		order.created_by_user = pathofast_user
		#order.reports[0].categories[0].items.add(Inventory::Item.new(barocde: pathofast_items[0]))
		order.save
		unless order.errors.full_messages.blank?
			puts "errors saving order FIRST TIME-----------------"
			puts order.errors.full_messages
			exit(1)
		end		

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		order.order_completed = Business::Order::YES
		order.created_by_user = pathofast_user
		order.created_by_user_id = pathofast_user.id.to_s
		order.save
		unless order.errors.full_messages.blank?
			puts "errors saving order SECOND TIME-------------------"
			puts order.errors.full_messages
			exit(1)
		end		
		## now we order another item group.

		## of the same type.
		## as before.
		## and try to add this item to that.
		pathofast_item_groups = Inventory::ItemGroup.find_organization_item_groups(pathofast_user.organization.id.to_s)

		puts "pathofast item groups are:"
		puts pathofast_item_groups.to_s

		newly_cloned_item_group = nil
		pathofast_item_groups.each do |item_group|
			if item_group.cloned_from_item_group_id.blank?
				if item_group.name == "BD SST Tube 5 tubes"
					## we want to make transaction and clone.
					newly_cloned_item_group = order_item_group({:user => pathofast_user, :item_group_id => item_group.id.to_s})

				end
			end
		end

		## now if you try to transfer an item to this.
		## it should not allow it.
		## we basically update that item.
		## so this should not be allowed at all.
		## validate this.
		item = Inventory::Item.find(pathofast_items[0].id.to_s)
		item.run_callbacks(:find)
		item.local_item_group_id = newly_cloned_item_group.id.to_s
		item.created_by_user = pathofast_user
		item.created_by_user_id = pathofast_user.id.to_s
		#item.save
		## i need to look into that.
		#puts item.errors.full_messages.to_s

		put inventory_item_path(item.id.to_s), params: {item: item.attributes.merge({local_item_group_id: newly_cloned_item_group.id.to_s}), :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		puts response.body.to_s


	end


	
=begin
	test " -- transfers single time between members of different organizations -- " do 
			
		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		
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
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2025-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.quantity_received = 2
		tr.created_by_user = @u
		tr.run_callbacks(:find)
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
		item.expiry_date = "2025-05-05"
		item.created_by_user = @u
		
		item.save
		puts "the item save errors are----------------------"
		puts item.errors.full_messages
		assert_equal true, item.errors.full_messages.blank?
		
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		post inventory_item_transfers_path, params: {item_transfer: {to_user_id: @u.id.to_s, reason: "Just for the heck of it.", name: "new item transfer", model_id: item.id.to_s, model_class: item.class.name.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal response.code.to_s, "201"

		## get the item.
		## check its organization ids.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		item = Inventory::Item.find(item.id.to_s)
		assert_equal 2, item.owner_ids.size
		assert_equal @u.organization.id.to_s, item.currently_held_by_organization

	end

	test " -- transfers item between members of different organizations -- " do 

		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		
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
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2025-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		#put inventory_transaction_path(tr.id.to_s), params: {transaction: {quantity_received: 2}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		tr = Inventory::Transaction.find(tr.id.to_s)
		tr.quantity_received = 2
		tr.created_by_user = @u
		tr.run_callbacks(:find)
		tr.save

		## so a local item_group should have been created.
		## which was cloned from this item group.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
		item.expiry_date = "2025-05-05"
		item.created_by_user = @u
		
		item.save
		puts "the item save errors are----------------------"
		puts item.errors.full_messages
		assert_equal true, item.errors.full_messages.blank?
		
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		## its like we are giving this to atif.
		post inventory_item_transfers_path, params: {item_transfer: {to_user_id: @atif.id.to_s, reason: "Just for the heck of it.", name: "new item transfer", model_id: item.id.to_s, model_class: item.class.name.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		assert_equal response.code.to_s, "201"

		## get the item.
		## check its organization ids.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		item = Inventory::Item.find(item.id.to_s)
		assert_equal 3, item.owner_ids.size
		assert_equal @atif.organization.id.to_s, item.currently_held_by_organization

	end

	test " transfers item group and all its component items to the other organization " do 

		item_type = Inventory::ItemType.new
		item_type.created_by_user = @atif
		item_type.name = "first item type"
		item_type.barcode_required = true
		item_type.virtual_units = 10
		
		item_type.save

		## now create another item type.
		item_type_two = Inventory::ItemType.new
		item_type_two.created_by_user = @atif
		item_type_two.name = "second item type"
		item_type_two.barcode_required = true
		item_type_two.virtual_units = 10
		
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
				expiry_date: "2025-01-01"	
			},
			{
				item_type_id: "second item type",
				quantity: 5,
				expiry_date: "2025-01-01"
			}
		]
		
		item_group.save
		assert_equal [], item_group.errors.full_messages

		
		tr = Inventory::Transaction.new
		tr.supplier_item_group_id = item_group.id.to_s
		tr.supplier_id = item_group.supplier_id
		tr.created_by_user = @u
		
		tr.save

		puts "these are the create transaction errors."
		puts tr.errors.full_messages.to_s

		## refresh the indices.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
		item.expiry_date = "2025-05-05"
		item.created_by_user = @u
		
		item.save
		puts "the item save errors are----------------------"
		puts item.errors.full_messages
		assert_equal true, item.errors.full_messages.blank?

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		## its like we are giving this to atif.
		post inventory_item_transfers_path, params: {item_transfer: {to_user_id: @atif.id.to_s, reason: "Transferring local item group.", name: "new item group transfer", model_id: local_item_group.id.to_s, model_class: local_item_group.class.name.to_s}, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: @headers

		puts "-------------- this is the response body -------------- "
		puts response.body.to_s
		assert_equal response.code.to_s, "201"

		## get the item.
		## check its organization ids.
		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

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
		

	

end