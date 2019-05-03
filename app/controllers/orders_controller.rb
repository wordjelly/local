class OrdersController < ApplicationController
	include Concerns::BaseControllerCOncern

	#respond_to :html, :json, :js

	#def new
	#	@order = Order.new
	#end

	#def edit
	#	@order = Order.find(params[:id])
	#	@order.run_callbacks(:find)
	#end

	# can we autoassing a name to it, and then do name id.
	# as that ?
	# good idea.
	def create
		@order = Order.new(id: SecureRandom.hex(10))

		@order.attributes = get_model_params
		if @order.errors.empty?
			response = @order.save
		end
		respond_to do |format|
			format.json do 
				render :json => {order: @order}
			end
			format.js do
				render :partial => "show", locals: {order: @order}
			end
		end
	end

	
	def update
		@order = Order.find(params[:id])
		@order.attributes = get_model_params
		if @order.errors.empty?
			save_result = @order.save
		end
		@order.run_callbacks(:find)		
		respond_to do |format|
			format.json do 
				render :json => {order: @order}
			end
			format.html do 
				render "show"
			end
			format.js do 
				render :partial => "show", locals: {order: @order}
			end
		end
	end

	## report can have many status ids.
	## we precreate these status ids.
	## they are aggregated and shown next to the tubes
	## when a status is clicked, a clone is created and attached.
	## which has this tube id.
	## or which has any of hte report ids, which this tube is reporting to.
	## aggregate by name, and show.
	## if the tube id one exists, then show it first.
	## otherwise show the other ones.

	def destroy
	end

	def show
		@order = Order.find(params[:id])
		@payment_status = Status.new(parent_id: @order.id.to_s)
		@payment_status.information_keys = {amount: nil}
		@order.run_callbacks(:find)

		respond_to do |format|
			format.html do 
				render "show"
			end
			format.json do 
				render :json => {order: @order.to_json}
			end
			format.pdf do
				render pdf: "receipt",
	               layout: "pdf/application.html.erb"
			end
		end
	end

	def index
		@orders = Order.all
		@orders.map{|c|
			begin
			 	c.run_callbacks(:find)
			rescue => e
				c.errors.add(:id, e.to_s)
			end
		}
	end

	def get_model_params
		if permitted_params[:order].blank?
			{}
		else
			permitted_params.fetch(:order)
		end
	end

	## what all is it going to have ?
	## multiple reports / packages from the dropdown
	## patient id from the dropdown.
	## that's it.
	def permitted_params
		params.permit(
			:id,
			{
			 	:order => [
			 		:start_time,
			 		:item_group_id,
			 		:item_group_action,
			 		:patient_id,
			 		{:template_report_ids => []},
			 		:tubes => [:item_requirement_name, :patient_report_ids, :template_report_ids, :barcode, :occupied_space]
			 	]
			}
		)
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