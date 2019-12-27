require "test_helper"
require "helpers/test_helper"

class OrdersControllerItemGroupTest < ActionDispatch::IntegrationTest

    include TestHelper
    
    setup do

        _setup({
			"bhargav_raut" => {
				"use_transaction_inventory" => true
			}
		})

    end


    test " -- adds item group to order -- " do 

    	pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		order = build_pathofast_patient_order(nil,nil,pathofast_user)
		order.save


		unless order.errors.full_messages.blank?
			puts "errors saving order THIS ONE------------"
			puts order.errors.full_messages
			exit(1)
		end

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


		newly_cloned_item_group.item_definitions.each do |id|
            item = Inventory::Item.new
            item.transaction_id = "abcdefgghe"
            item.supplier_item_group_id = newly_cloned_item_group.id.to_s
            item.local_item_group_id = newly_cloned_item_group.id.to_s
            item.item_type_id = id["item_type_id"]
            puts "searcing for the item type--------------->#{item.item_type_id}"
            item.categories = Inventory::ItemType.find(id["item_type_id"]).categories
            item.barcode = "12345"
            item.expiry_date = "2025-05-05"
            item.created_by_user = pathofast_user
            item.created_by_user_id = pathofast_user.id.to_s
            item.save
            unless item.errors.full_messages.blank?
                puts "there are errors saving the item."
                puts "error "
                puts "errors: #{item.errors.full_messages}"
                exit(1)
            end
        end

		## now we add this to the order.
		## okay so we need to add some items to it.
		## that's why nothing is being generated.
		## we can add a couple of items to it.
		## no problems.

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		order.local_item_group_id = newly_cloned_item_group.id.to_s
		order.created_by_user = pathofast_user
		order.created_by_user_id = pathofast_user.id.to_s

		put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		puts response.body.to_s

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		order = Business::Order.find(order.id.to_s)

		assert_equal 1, order.categories[0].items.size
		assert_equal 5, order.categories[0].items[0].applicable_to_report_ids.size

    end

    test " -- item group cannot be reused in two different orders -- " do 

    	pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		order = build_pathofast_patient_order(nil,nil,pathofast_user)
		order.save


		unless order.errors.full_messages.blank?
			puts "errors saving order THIS ONE------------"
			puts order.errors.full_messages
			exit(1)
		end

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


		newly_cloned_item_group.item_definitions.each do |id|
            item = Inventory::Item.new
            item.transaction_id = "abcdefgghe"
            item.supplier_item_group_id = newly_cloned_item_group.id.to_s
            item.local_item_group_id = newly_cloned_item_group.id.to_s
            item.item_type_id = id["item_type_id"]
            puts "searcing for the item type--------------->#{item.item_type_id}"
            item.categories = Inventory::ItemType.find(id["item_type_id"]).categories
            item.barcode = "12345"
            item.expiry_date = "2025-05-05"
            item.created_by_user = pathofast_user
            item.created_by_user_id = pathofast_user.id.to_s
            item.save
            unless item.errors.full_messages.blank?
                puts "there are errors saving the item."
                puts "error "
                puts "errors: #{item.errors.full_messages}"
                exit(1)
            end
        end

		## now we add this to the order.
		## okay so we need to add some items to it.
		## that's why nothing is being generated.
		## we can add a couple of items to it.
		## no problems.

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		order.local_item_group_id = newly_cloned_item_group.id.to_s
		order.created_by_user = pathofast_user
		order.created_by_user_id = pathofast_user.id.to_s
		order.save
		unless order.errors.full_messages.blank?
            puts "there are errors saving the item."
            puts "error "
            puts "errors: #{order.errors.full_messages}"
            exit(1)
        end

        ## now we want one more order.
        ## and this time we add the same item group.

        ##################### ORDER TWO ##########################

        order_two = build_pathofast_patient_order(nil,nil,pathofast_user)
		order_two.save


		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		order_two = Business::Order.find(order_two.id.to_s)
		order_two.run_callbacks(:find)
		order_two.local_item_group_id = newly_cloned_item_group.id.to_s
		order_two.created_by_user = pathofast_user
		order_two.created_by_user_id = pathofast_user.id.to_s

		put business_order_path(order_two.id.to_s), params: {order: order_two.attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		puts response.body.to_s

		assert_equal "404", response.code.to_s


    end    

	test " -- item group with multiple categories, gets correctly added to each category" do 

		pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		local_item_group = build_pathofast_collection_packet(user: pathofast_user)

		o = build_pathofast_t3_order(nil,pathofast_user,nil)

		order = Business::Order.find(o.id.to_s)
		order.local_item_group_id = local_item_group.id.to_s

		put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		puts response.body.to_s

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		order = Business::Order.find(order.id.to_s)
		## now we find the order.
		order.categories.each do |category|
			puts "category name:#{category.name}"
			puts "items are"
			category.items.each do |it|
				puts it.attributes
			end
			assert_equal 1, category.items.size
		end
		assert_equal 1, order.trigger_lis_poll
	end

    test " -- trigger lis poll not set if no item/category/report changes on the order -- " do 
    	
    	pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		local_item_group = build_pathofast_collection_packet(user: pathofast_user)

		o = build_pathofast_t3_order(nil,pathofast_user,nil)

		order = Business::Order.find(o.id.to_s)
		order.run_callbacks(:find)
		order.local_item_group_id = local_item_group.id.to_s
		order.created_by_user = pathofast_user
		order.created_by_user_id = pathofast_user.id.to_s
		order.save

		unless order.errors.full_messages.blank?
			puts "errors: #{order.errors.full_messages} while saving the order"
			exit(1)
		end

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		#assert_equal 1, order.trigger_lis_poll

		#put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		#assert_equal "204", response.code.to_s

		#puts response.body.to_s

		#Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		#order.reports[0].requirements[0].categories[1].use_category_for_lis = 1

		put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		puts response.body.to_s

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		assert_equal -1, order.trigger_lis_poll 
    end


    test  " -- trigger lis poll set to true, when category priority is changed inside a report -- " do 


    	pathofast_user = User.where(:email => "bhargav.r.raut@gmail.com").first

		local_item_group = build_pathofast_collection_packet(user: pathofast_user)

		o = build_pathofast_t3_order(nil,pathofast_user,nil)

		order = Business::Order.find(o.id.to_s)
		order.run_callbacks(:find)
		order.local_item_group_id = local_item_group.id.to_s
		order.created_by_user = pathofast_user
		order.created_by_user_id = pathofast_user.id.to_s
		order.save

		unless order.errors.full_messages.blank?
			puts "errors: #{order.errors.full_messages} while saving the order"
			exit(1)
		end

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		#assert_equal 1, order.trigger_lis_poll

		#put business_order_path(order.id.to_s), params: {order: order.attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		#assert_equal "204", response.code.to_s

		#puts response.body.to_s

		#Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		order.reports[0].requirements[0].categories[1].use_category_for_lis = 1

		put business_order_path(order.id.to_s), params: {order: order.deep_attributes, :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		puts response.body.to_s

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast*"

		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		assert_equal 1, order.trigger_lis_poll

    end

end