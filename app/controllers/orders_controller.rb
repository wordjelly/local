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
	end

	def create
		@order = Order.new
		@order.add_remove_reports(params)
		@order.patient_id = params[:patient_id]
		response = @order.save
		respond_to do |format|
			format.json do 
				render :json => {order: @order}
			end
			format.js do
				render :partial => "show"
			end
		end
	end

	## so we have to have some kind of authentication
	## we can use amazon incognito.
	## and do a simple admin thing.
	## admin super.
	## kamthe's login, so we add that as a mixin all throughout.
	## to have a access_by?
	## billing -> test price
	## user prices.
	## letter head reports
	## add a logo or whatever.
	## and also add the nail analysis, our product pages,
	## and other information stuff, all into this site.
	## so we can have a settings page, where we add our letter head
	## logo
	## and signature for the reports
	## thereafter, its just about assigning a user to each report

	def update
		@order = Order.find(params[:id])
		@order.load_reports
		@order.load_patient
		@order.load_items
		@order.add_remove_reports(params)
		@order.add_barcodes(params)
		@order.save
		respond_to do |format|
			format.json do 
				render :json => {order: @order}
			end
			format.js do 
				render :partial => "show"
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