class EquipmentController < ApplicationController
	
	## next step give autocomplete on the report name.
	## and auto assign the id.
	respond_to :html, :json, :js

	def new
		@equipment = Equipment.new
	end

	def edit
		@equipment = Equipment.find(params[:id])
	end

	def create
		@equipment = Equipment.new(permitted_params["equipment"])
		@equipment.id = @equipment.name unless @equipment.name.blank?
		response = @equipment.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@equipment = Equipment.find(params[:id])
		
		@equipment.attributes = permitted_params[:equipment].except(:name)
		
		@equipment.save

		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end


	def destroy
	end


	def show
		@equipment = Equipment.find(params[:id])
	end


	def index
		@equipments = Equipment.all
	end

	def permitted_params
		params.permit(:id , {:equipment => [:name, :definitions => [:report_id, :report_name, :priority]]})
	end

end