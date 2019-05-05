class TestsController < ApplicationController
	
	include Concerns::BaseControllerConcern


=begin

	respond_to :html, :json, :js

	def new
		@test = Test.new
	end

	def edit
		@test = Test.find(params[:id])
	end

	def create
		@test = Test.new(permitted_params["test"].merge(:search_options => ["Add To Report","Remove From Report"]))
		response = @test.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@test = Test.find(params[:id])
		@test.load_normal_ranges
		@test.update_attributes(permitted_params["test"])
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy

	end

	def show
		@test = Test.find(params[:id])
		@test.load_normal_ranges
	end

	def index
		@tests = Test.all
	end

	
	def permitted_params
		params.permit(:id , {:test => [:name,:lis_code,:description,:price]})
	end

=end

end