class ItemTypesController  < ApplicationController

	respond_to :html, :json, :js

	def new
		@item_type = ItemType.new
	end

	def edit
		@item_type = ItemType.find(params[:id])
	end

	def create
		@item_type = ItemType.new(permitted_params["item_type"])
		@item_type.id = @item_type.name unless @item_type.name.blank?
		response = @item_type.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@item_type = ItemType.find(params[:id])
		
		@item_type.attributes = permitted_params["item_type"].except(:name)
		
		@item_type.save

		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def show
		@item_type = ItemType.find(params[:id])
		
	end

	def index
		@item_types = ItemType.all
	end

	
	def permitted_params
		params.permit(:id , {:item_type => [:name]})
	end


end