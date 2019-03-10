class ItemGroupsController < ApplicationController

	respond_to :html, :js, :json

	def new
		@item_group = ItemGroup.new
	end

	def edit
		@item_group = ItemGroup.find(params[:id])
	end

	def create
		@item_group = ItemGroup.new(permitted_params["item_group"])
		response = @item_group.save
		@item_group.load_associated_items
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@item_group = ItemGroup.find(params[:id])
		@item_group.update_attributes(permitted_params["item_group"])
		@item_group.load_associated_items
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end


	def destroy
	end


	def show
		@item_group = ItemGroup.find(params[:id])
		@item_group.load_associated_items
	end


	def index
		@item_groups = ItemGroup.all
		@item_groups.map{|c|
		 c.load_associated_items
		}
	end

	def permitted_params
		params.permit(:id , {:item_group => [ {:item_ids => []}, :group_type, :barcode ]})
	end

	

end