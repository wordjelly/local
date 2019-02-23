class NormalRangesController < ApplicationController
	
	respond_to :html

	def new
		@normal_range = NormalRange.new(permitted_params["normal_range"])
	end

	def show
		@normal_range = NormalRange.find(:id)
		@normal_range.load_test_name
	end

	def create
		@normal_range = NormalRange.new(permitted_params["normal_range"])
		@normal_range.save
		@normal_range.load_test_name
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@normal_range = NormalRange.find(:id)
		@normal_range.assign_attributes(permitted_params[:normal_range])
		@normal_range.save
		@normal_range.load_test_name
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
		params.permit(:id,{:normal_range => [:test_id, :test_name, :min_age, :max_age, :sex]})
	end

end