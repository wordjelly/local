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
		@status.attributes = get_model_params
		@status.parent_ids = (get_model_params[:parent_ids] || [])
		@status.save
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

	def get_model_params
		permitted_params[:status] || {}
	end

	def show
		@status = Status.find(params[:id])
		unless params[:status].blank?
			@status.show_reports_modal = params[:status][:show_reports_modal]
		end
		@status.show_reports_modal ||= false
		@status.run_callbacks(:find)
		
	end

	def index
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

		@statuses = @statuses.each_with_index.map{|c,k|
			s = Status.new(c["_source"])
			s.id = c["_id"]
			c = s
			s.run_callbacks(:find)
			s.higher_priority = Status.higher_priority(@statuses,k)
			s.lower_priority = Status.lower_priority(@statuses,k)
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
		params.permit(:id , {:status => [:name, {:tag_ids => []}, {:parent_ids => []},:report_id,:item_id,:item_group_id,:order_id,:response,:patient_id,:priority,:requires_image, :numeric_value, :text_value, :show_reports_modal]})
	end


end