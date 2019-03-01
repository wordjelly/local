class OrdersController < ApplicationController
	
	respond_to :html, :json, :js

	def new
		@order = Order.new
	end

	def edit
		@order = Order.find(params[:id])
	end

	def create
		@order = Order.new(permitted_params["order"])
		response = @order.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@order = Order.find(params[:id])
		@order.attributes = (permitted_params["order"])
		@order.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def show
		@order = Order.find(params[:id])
	end

	def index
		@orders = Order.all
	end

	## what all is it going to have ?
	## multiple reports / packages from the dropdown
	## patient id from the dropdown.
	## that's it.
	def permitted_params
		params.permit(:id , {:order => [:report_name,:patient_id,:test_id,:item_requirement_id, :test_id_action, :item_requirement_action]})
	end


end

## ORDER LIFECYCLE
## ADD TESTS
## COLLECT
## ASSIGN ITEM GROUPS / ITEMS - WITH AMOUNTS, AND PHOTOS(update those items.)
## AUTOMATICALLY SWITCHES TO PROCESSING
## ON VERIFICATION OF ALL TESTS -> SWITCHES TO COMPLETED
## IN MIDWAY, FOLLOWING THINGS ARE POSSIBLE ->
## ADD MORE TESTS -> if this is triggered, will check, if items exist, and have sufficient volume of consumables, CHANGE ITEM TYPES, REMOVE CERTAIN TESTS.