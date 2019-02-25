class LocationsController  < ApplicationController

	respond_to :html, :json, :js

	def new
		@location = Location.new
	end

	def edit
		@location = Location.find(params[:id])
	end

	def create
		@location = Location.new(permitted_params["location"])
		response = @location.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@location = Location.find(params[:id])
		
		@location.update_attributes(permitted_params["location"])
		
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def show
		@location = Location.find(params[:id])
		
	end

	def index
		@locations = Location.all
	end

	
	def permitted_params
		params.permit(:id , {:location => [:name]})
	end


end