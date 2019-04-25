class ImagesController < ApplicationController
	
	respond_to :html

	def new
		@image = Image.new(permitted_params["image"])
	end

	def show
		@image = Image.find(:id)
		@image.load_test_name
	end

	def create
		@image = Image.new(permitted_params["image"])
		@image.save
		respond_to do |format|
			format.html do 
				render "show"
			end
			format.text do 
				render :plain => @image.signed_request[:signature]
			end
		end
	end

	def update
		@image = Image.find(:id)
		@image.update_attributes(permitted_params[:image])
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy

	end

	def index

	end

	def permitted_params
		params.permit(Image.permitted_params)
	end

end