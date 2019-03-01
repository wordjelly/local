class ReportsController < ApplicationController
	
	respond_to :html, :json, :js

	def new
		@report = Report.new
	end

	def edit
		@report = Report.find(params[:id])
		@report.load_tests
		@report.load_item_requirements
	end

	def create
		@report = Report.new(permitted_params["report"])
		response = @report.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@report = Report.find(params[:id])
		## so the before update thing does not work.
		@report.attributes = permitted_params["report"]
		@report.save
		#@report.load_tests
		#@report.load_item_requirements
		respond_to do |format|
			format.html do 
				redirect_to report_path(@report.id.to_s)
			end
		end
	end

	def destroy
	end

	def show
		@report = Report.find(params[:id])
		@report.load_tests
		@report.load_item_requirements
	end

	def index
		@reports = Report.all
	end

	## so here it has to refer to tests, and item requirements, 
	## and on clicking it it has to do the autocomplete.
	## so we will give an add or a remove.
	## only add, and a remove option also can be giben.
	
	def permitted_params
		## we can add one test or item_requirement at a time.
		## the item requirements.
		params.permit(:id , {:report => [:name,:test_id,:item_requirement_id, :test_id_action, :item_requirement_id_action, :price]})
	end


end