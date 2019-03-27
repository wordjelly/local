class StatusesController  < ApplicationController

	respond_to :html, :json, :js

	def new
		puts "permitted_params"
		puts permitted_params.to_s
		@status = Status.new(get_model_params)
	end

	def edit
		@status = Status.find(params[:id])
	end

	## so now first order calculates, the pending
	## payment
	## then it goes to the status to make the payment
	## there the payment is made
	## and then order also has an endpoint to print a 
	## receipt
	## on making payment, receipt is generated and printed
	## by using wickedpdf.
	## we can make it go to the .pdf extension
	## on submit?
	## and it gives you the receipt.

	def create
		@status = Status.new(permitted_params["status"])
		response = @status.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@status = Status.find(params[:id])
		@status.run_callbacks(:find)
		@status.attributes(permitted_params["status"])
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def make_payment
		@status = Status.new(get_model_params)
	end

	def show
		@status = Status.find(params[:id])
		#puts "running callbacks."
		@status.run_callbacks(:find)
	end

	def index
		## gives you all the statuses where there is no patient_id.
		## so ignores all the bills.
		## also those statuses which don't have a 
		## report_id.

		@statuses = Status.search({
			sort: {
				priority: {
					order: "asc"
				}
			},
			query: {
				bool: {
					filter: {
						match_all: {}
					},
					must_not: [
						{	
							exists: {
								field: "patient_id"
							}	
						},
						{
							exists: {
								field: "report_id"
							}
						},
						{
							terms: {
								name: ["payment","bill"]
							}
						}
					]
				}
			}
		})

		## what all do you want to see in a status
		## the reports.
		## that are rgiegster on it.

		@statuses = @statuses.map{|c|
			s = Status.new(c["_source"])
			s.id = c["_id"]
			c = s
			s.run_callbacks(:find)
			s
		}

	end

	def get_model_params
		if permitted_params["status"]
			permitted_params["status"]
		else
			{}
		end
	end

	
	def permitted_params
		params.permit(:id , {:status => [:name,:parent_id,:report_id,:item_id,:item_group_id,:order_id,:response,:patient_id,:priority,:requires_image, :numeric_value, :text_value]})
	end


end