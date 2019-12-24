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

		## now we add this to the order.
		order = Business::Order.find(order.id.to_s)
		order.run_callbacks(:find)
		order.local_item_group_id = newly_cloned_item_group.id.to_s
		order.created_by_user = pathofast_user
		order.created_by_user_id = pathofast_user.id.to_s

		put business_order_path(order.id.to_s), params: {order: order.attributes), :api_key => @ap_key, :current_app_id => "testappid" }.to_json, headers: get_user_headers(@security_tokens,pathofast_user)

		assert_equal "204", response.code.to_s

		puts response.body.to_s

    end

=begin
    test " -- validates items from the item group -- " do 

    end

    test " -- item group cannot be reused in two different orders -- " do 

    end    
        
    test " -- changing category priority triggers lis download -- " 
    do 
        ## shouldnt be too hard to manage this part.
        ## then we go for report formats -
        ## start with hemogram, esr, etc.
    end
=end

end