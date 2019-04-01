class ItemsController  < ApplicationController

	respond_to :html, :json, :js

	def new
		@item = Item.new
	end

	def edit
		@item = Item.find(params[:id])
	end

	def create
		@item = Item.new(permitted_params["item"])
		response = @item.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@item = Item.find(params[:id])
		@item.update_attributes(permitted_params["item"])
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end


	def destroy
	end


	def show
		@item = Item.find(params[:id])		
		@item.run_callbacks(:find)
	end


	def index
		@items = Item.all
		@items.map{|c| c.load_images}
	end

	
	def permitted_params
		params.permit(:id , {:item => [:item_type, :location, :filled_amount, :expiry_date, :contents_expiry_date, :barcode]})
	end


end