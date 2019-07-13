class ImagesController < ApplicationController
		
	## to require basic api authentication for any controller.
	include Auth::Concerns::DeviseConcern
	before_action :do_before_request

	respond_to :html, :json


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
		@errors = @image.errors
		respond_to do |format|
			format.html do 
				render "show"
			end
			format.json do 
				if @errors.full_messages.blank?
					render :json => {signature: @image.signed_request[:signature], errors: @errors.full_messages}
				else
					render :json => {signature: nil, errors: @errors.full_messages}
				end
			end
			format.text do 
				if @errors.full_messages.blank?
					render :plain => @image.signed_request[:signature]
				else
					render :plain => @errors.full_messages.to_s
				end
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