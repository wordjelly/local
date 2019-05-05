class OrdersController < ApplicationController
	include Concerns::BaseControllerConcern

=begin
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
=end
	
=begin
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
=end

=begin
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
=end

=begin
	def get_model_params
		if permitted_params[:order].blank?
			{}
		else
			permitted_params.fetch(:order)
		end
	end
=end

end

## ORDER LIFECYCLE
## ADD TESTS
## COLLECT
## ASSIGN ITEM GROUPS / ITEMS - WITH AMOUNTS, AND PHOTOS(update those items.)
## AUTOMATICALLY SWITCHES TO PROCESSING
## ON VERIFICATION OF ALL TESTS -> SWITCHES TO COMPLETED
## IN MIDWAY, FOLLOWING THINGS ARE POSSIBLE ->
## ADD MORE TESTS -> if this is triggered, will check, if items exist, and have sufficient volume of consumables, CHANGE ITEM TYPES, REMOVE CERTAIN TESTS.