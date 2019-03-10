class OrdersController < ApplicationController
	
	respond_to :html, :json, :js

	def new
		@order = Order.new
	end

	def edit
		@order = Order.find(params[:id])
		@order.load_patient
		@order.load_reports
		@order.load_items
		puts @order.item_requirements.to_s
	end

	def create
		@order = Order.new
		@order.add_remove_reports(params)
		@order.patient_id = params[:patient_id]
		puts "the order errors are: -----------------"
		puts @order.errors.full_messages.to_s
		if @order.errors.empty?
			puts "saving order"
			puts "item requirements."
			puts @order.item_requirements.to_s
			response = @order.save
			puts "order save errros"
			puts response.to_s
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
		@order.load_reports
		@order.load_patient
		@order.load_items
		@order.add_remove_reports(params)
		@order.add_barcodes(params)
		#puts "after add barcodes does it have errors?"
		#puts @order.errors.full_messages.to_s
		if @order.errors.empty?
			save_result = @order.save
		end
		#puts "save result is: #{save_result}----------------------------------------"
		respond_to do |format|
			format.json do 
				render :json => {order: @order}
			end
			format.js do 
				render :partial => "show", locals: {order: @order}
			end
		end
	end

	## how much longer ?
	## orders -> statuses
	## login -> 


	def destroy
	end

	def show
		@order = Order.find(params[:id])
		@order.load_patient
		@order.load_reports
		@order.load_items
		puts "The order item requirements are:"
		puts @order.item_requirements.to_s
	end

	def index
		@orders = Order.all
		@orders.map{|c|
		 	c.load_patient
		 	c.load_reports
		 	c.load_items
		}
	end

	## what all is it going to have ?
	## multiple reports / packages from the dropdown
	## patient id from the dropdown.
	## that's it.
	def permitted_params
		puts "params are:"
		puts params.to_s
		params.permit(:id , {:order => [:patient_id, {:template_report_ids => []}]})
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