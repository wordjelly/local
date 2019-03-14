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
		
		## we also have to load the image concern.
		## a particular status type may require an image to be present
		## 
		
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def show
		@status = Status.find(params[:id])
		puts "running callbacks."
		@status.run_callbacks(:find)
		ptus "finished running callbacks."
	end

	def index
		@statuses = Status.all
		@statuses.map{|c|
			c.run_callbacks(:find)
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
		params.permit(:id , {:status => [:name,:parent_id,:report_id,:item_id,:item_group_id,:order_id,:response,:patient_id,:priority,:requires_image]})
	end


end