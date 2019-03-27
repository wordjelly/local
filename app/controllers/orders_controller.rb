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
		@order.generate_account_statement
		## so we need a status picker
		## and a sorter
		## this can be seen in a tab called patient
		## reports.
		## so it will be showing only those with a patient id.
		## so we go to reports index
		## with a flag.
		## 
	end

	def create
		@order = Order.new(id: SecureRandom.hex(10))
		@order.add_remove_reports(params)
		
		@order.patient_id = params[:patient_id]
		#puts "the order errors are: -----------------"
		#puts @order.errors.full_messages.to_s
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
		@order.attributes = permitted_params(:order)
		if @order.errors.empty?
			save_result = @order.save
		end
		@order.generate_account_statement
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
		@order.load_patient
		@order.load_reports
		@order.load_items
		@order.generate_account_statement
		@payment_status = Status.new(parent_id: @order.id.to_s)
		@payment_status.information_keys = {amount: nil}
		@order.generate_pdf

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
		 	c.load_patient
		 	c.load_reports
		 	c.load_items
		 	c.generate_account_statement
		}
	end

	## what all is it going to have ?
	## multiple reports / packages from the dropdown
	## patient id from the dropdown.
	## that's it.
	def permitted_params
		## so now we can add a barcode.
		## we just have to check that the barcodes are not present in any other order.
		params.permit(:id , {:order => [:item_group_id, :item_group_action, :tubes => [:item_requirement_name, :patient_report_ids, :template_report_ids, :barcode, :occupied_space] :patient_id, {:template_report_ids => []}]})
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