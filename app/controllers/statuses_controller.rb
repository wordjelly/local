class StatusesController  < ApplicationController

	respond_to :html, :json, :js

	def new
		@status = Status.new
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
		
		@status.update_attributes(permitted_params["status"])
		
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
		
	end

	def index
		@statuss = Status.all
	end

	
	def permitted_params
		params.permit(:id , {:status => [:name]})
	end


end