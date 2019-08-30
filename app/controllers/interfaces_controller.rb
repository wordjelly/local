class InterfacesController < ApplicationController

	before_action :authorize_interface

	## thrown from self#authorize_interface when the security_key does not match any results
	def unauthorized(error = 'Unauthorized')
	   raise ActionController::RoutingError.new(error)
	end

	## thrown from the self#authorize_interface when the organization has disabled_lis in its organization settings.
	def lis_disabled(error = 'Disabled')
	   raise ActionController::RoutingError.new(error)
	end

	def show
		items = params[:items].map{|c| 
			Inventory::Item.new(c)
		}
		orders = Business::Order.find_orders(items)
		respond_to do |format|
			format.json do 
				render :json => {:orders => orders}
			end
		end
	end

	def update
		orders = Business::Order.find_orders(params[:orders].map{|c| Business::Order.new(c)})
		orders.each_with_index{|order,key|

		}
	end

	def authorize_interface
		search_results = Organization.search({
			size: 1,
			query: {
				bool: {
					must: [
						{
							term: {
								lis_security_key: params[:lis_security_key]
							}
						}
					],
					should: [
						{
							term: {
								lis_enabled: Organization::YES
							}
						}
					]
				}	
			}
		})

		if search_results.response.hits.hits.size == 1
			obj = results.response.hits.hits[0]
			obj = get_resource_class.new(obj["_source"])
			obj.id = obj["_id"]
			obj.run_callbacks(:find)
			if obj.lis_enabled == Organization::NO
				lis_disabled
			end
		elsif search_results.response.hits.hits.size > 1
			unauthorized
		else
			unauthorized
		end
	end	



	def permitted_params
		[
			:lis_code,
			{:items => Inventory::Item.interface_permitted_params},
			{:reports => Diagnostics::Report.interface_permitted_params},
			{:controls => Diagnostics::Control.interface_permitted_params}
		]
	end

end