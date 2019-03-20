class ItemRequirementsController  < ApplicationController

	respond_to :html, :json, :js

	def new
		@item_requirement = ItemRequirement.new
	end

	def edit
		@item_requirement = ItemRequirement.find(params[:id])
	end

	def create
		@item_requirement = ItemRequirement.new(permitted_params["item_requirement"])
		@item_requirement.id = @item_requirement.name unless @item_requirement.name.blank?
		response = @item_requirement.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@item_requirement = ItemRequirement.find(params[:id])
		
		@item_requirement.attributes = permitted_params[:item_requirement].except(:name)
		
		@item_requirements.save

		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end


	def destroy
	end


	def show
		@item_requirement = ItemRequirement.find(params[:id])
		@item_requirement.load_associated_reports	
	end


	def index
		@item_requirements = ItemRequirement.all
		@item_requirements.map{|c|
		 c.load_images
		 c.load_associated_reports
		}
	end

	def permitted_params
		params.permit(:id , {:item_requirement => [:name, :item_type, :optional, :amount, :priority, :definitions => [:report_id, :report_name, :amount, :priority]]})
	end


end