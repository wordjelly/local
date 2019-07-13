class TagsController  < ApplicationController

	include Concerns::BaseControllerConcern

=begin
	respond_to :html, :json, :js

	def new
		@tag = Tag.new
	end

	def edit
		@tag = Tag.find(params[:id])
	end

	def create
		@tag = Tag.new(permitted_params["tag"])
		@tag.id = @tag.name unless @tag.name.blank?
		response = @tag.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@tag = Tag.find(params[:id])
		
		@tag.attributes = permitted_params["tag"].except(:name)
		
		@tag.save

		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def show
		@tag = Tag.find(params[:id])
		
	end

	def index
		@tags = Tag.all
	end

	
	def permitted_params
		params.permit(:id , {:tag => [:name]})
	end
=end

end