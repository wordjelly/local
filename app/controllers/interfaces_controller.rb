class InterfacesController < ApplicationController

	skip_before_action :verify_authenticity_token
	before_action :authorize_interface_and_set_organization

	def index
		if @authorization_error.blank?
			result = Business::Order.find_orders_changed_for_lis(params,@organization)
			orders = result[:orders]
			size = result[:size]
		end
		respond_to do |format|
			format.json do 
				unless @authorization_error.blank?
					render :json => {errors: @authorization_error}, status: :unauthorized
				else
					render :json => params.merge({:orders => orders, :size => size})
				end
			end				
		end
	end

	## @called_from : intended to be called by the lab_local server computer.
	## @params : see permitted params, intended to carry an array of items, each item having only one permitted parameter called 'code', this can be either the barcode or the generated_code (use_code), barcode taking preceedence. 
	## @return[Array:Business::Order] array of business orders, which have any of those items in them.
	def show
		if @authorization_error.blank?
			items = params[:items].map{|c| 
				Inventory::Item.new(c)
			}
			orders = Business::Order.find_orders(items)
		end
		respond_to do |format|
			format.json do 
				unless @authorization_error.blank?
					render :json => {errors: @authorization_error}, status: :unauthorized
				else
					render :json => {:orders => orders}
				end
			end
		end
	end

	def update

	end

	## @called_from : intended to be called from the local lab LIS
	## @params : see the permitted params, intended that the local lab LIS should send in an array of orders.
	## Each order MUST contain the order_id, and should contain a reports array, the report should have only one attribute i.e the tests array and each test should have just two attributes, i.e the lis_code and the result_raw.
	## the reports dont need to have an id, and the tests also dont need to have an id.
	## example:
	#{
	#	orders: [
	#		{
	#			"_id" : "abc", // REQUIRED
	#			"reports" : [
	#				{
	#					"tests" : [
	#						{
	#							"lis_code" : "xyz",
	#							"result_raw" : abc
	#						}
	#					]
	#				}
	#			]
	#		},
	#		{
	#			...
	#		}
	#	]
	#}
	# it is the responsibility of the lab local lis to check if the orders being returned have the updated values, and keep track of which values need to be reattempted/which tests are already verified etc, hence the updated orders are returned.
	def update_many

		if @authorization_error.blank?
			#puts "the permitted params are:"
			#puts params.to_s
			incoming_orders = permitted_params[:orders].map{|c| o = Business::Order.new(c)
			 }
			orders = Business::Order.find_orders({orders: incoming_orders})
			## find_orders returns a hash keyed by id.
			orders.keys.each do |order_id|
				order = orders[order_id]
				order.update_lis_results(incoming_orders.select{|c| c.id.to_s == order_id}[0])
				order.skip_owners_validations = true	

				order.validations_to_skip = ["set_changed_for_lis","cascade_id_generation"]

				if order.valid?
					Business::Order.add_bulk_item({
						update: {
							_index: Business::Order.index_name,
							_type: Business::Order.document_type,
							_id: order.id.to_s,
							data: {doc: order.deep_attributes(true,false)}
						}
					})
				end
			end
		
			Business::Order.flush_bulk
			Elasticsearch::Persistence.client.indices.refresh index: Business::Order.index_name
			updated_orders = Business::Order.find_orders({orders: incoming_orders})
			updated_orders.keys.each do |updated_order_id|
				updated_orders[updated_order_id].lis_updates_done?(orders[updated_order_id].tests_changed_by_lis)
			end
		end

		#puts "updated orders is a #{updated_orders.class}"
		#puts "to json----------------------->"
		#puts updated_orders.to_json
		#exit(1)

		respond_to do |format|
			format.json do 
				unless @authorization_error.blank?
					render :json => {errors: @authorization_error}, status: :unauthorized
				else
					render :json => params.merge({:orders => updated_orders})
				end
			end
		end
		
	end


	def authorize_interface_and_set_organization
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

		puts "the search result response hits size is:"
		puts search_results.response.hits.hits.to_s

		if search_results.response.hits.hits.size == 1
			obj = search_results.response.hits.hits[0]
			if obj["_type"] == Organization.document_type
				@organization = Organization.new(obj["_source"])
				@organization.id = obj["_id"]
				@organization.run_callbacks(:find)
			end
			if obj.lis_enabled == Organization::NO
				@authorization_error = "lis is disabled"
			end
		else 
			@authorization_error = "not authorized"
		end
	end	

	## from -> if this is a part of a bunch of requests, then from , tells how many results to skip (only applicable for the index query.)
	## last_polled_at -> from the lis, what is its last polled at time.
	## lis_security_key -> the security key of the lis
	## the query side is from,to,skip.
	## update side -> orders.
	def permitted_params
		params.permit([
			:from_epoch,
			:to_epoch,
			:skip,
			:size,
			:lis_security_key,
			{:orders => Business::Order.permitted_params[1][:order]},
			{:items => Inventory::Item.interface_permitted_params},
			{:controls => Diagnostics::Control.interface_permitted_params}
		]).to_h
	end

end