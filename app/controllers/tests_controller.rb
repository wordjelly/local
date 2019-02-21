class TestsController < ApplicationController
	
	respond_to :html, :json, :js

	def new
		@test = Test.new
	end

	def edit
	end

	def create
		@test = Test.new(permitted_params)
		@test.save
	end

	def update
		## now how to update the existing test ?
		## with a script ?
	end

	def destroy
	end

	def show
		@test = Test.find(params[:id])
	end

	## this endpoint has to also be there.
	## and we want patient and tube ids on autocomplete.
	def search
	end

	def index
		@tests = Test.all
	end

	
	def permitted_params
		params.permit(:id , {:test => [:name,:lis_code,:description,:price]})
	end


end