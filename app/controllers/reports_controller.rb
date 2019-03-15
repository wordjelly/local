class ReportsController < ApplicationController
	
	respond_to :html, :json, :js

	def new
		@report = Report.new
	end

	def edit
		@report = Report.find(params[:id])
		@report.run_callbacks(:find)
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
		@report.run_callbacks(:find)
		## so the before update thing does not work.
		@report.attributes = permitted_params["report"]
		puts "report status ids after assigning attributes are"
		puts @report.attributes.to_s
		save_response = @report.save
		puts "save response: #{save_response}"
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
		@report.run_callbacks(:find)
		@report.load_tests
		@report.load_item_requirements
	end

	def index
		@reports = Report.all
		@reports.map{|c|
			c.run_callbacks(:find)
		}
	end

	## so here it has to refer to tests, and item requirements, 
	## and on clicking it it has to do the autocomplete.
	## so we will give an add or a remove.
	## only add, and a remove option also can be giben.
	def permitted_params
		params.permit(:id , {:report => [:name,:test_id,:item_requirement_id, :test_id_action, :item_requirement_id_action, :price, {:status_ids => []}]})
	end


end