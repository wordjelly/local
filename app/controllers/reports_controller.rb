class ReportsController < ApplicationController
	
	respond_to :html, :json, :js

	def new
		@report = Report.new
	end

	def edit
		@report = Report.find(params[:id])
		@report.run_callbacks(:find)
		puts "these are the item requirement ids."
		puts @report.item_requirement_ids.to_s
	end

	def create
		@report = Report.new(get_model_params)
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
		@report.attributes = get_model_params
		save_response = @report.save
		puts "save response:"
		puts save_response.to_s
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
	end

	def index

		if permitted_params[:report]
			report = Report.new(get_model_params)
			must_clauses = report.build_query
		end

		@reports = Report.search({
			query: {
				bool: {
					must: must_clauses
				}
			}
		})

		@reports.map{|c|
			c.run_callbacks(:find)
		}
	end

	def get_model_params
		pp = params.fetch(:report)
		pp[:tag_ids] ||= []
		pp[:test_ids] ||= []
		pp[:item_requirement_ids] ||= []
		pp
	end

	## its going to be an ajax request anyways.
	## if we make another controller it won't matter.
	## so here it has to refer to tests, and item requirements, 
	## and on clicking it it has to do the autocomplete.
	## so we will give an add or a remove.
	## only add, and a remove option also can be giben.
	def permitted_params
		params.permit(:id , {:report => [:name,:test_id,:item_requirement_id, :test_id_action, :item_requirement_id_action, :price, {:status_ids => []}, {:tag_ids => []} ,{:test_ids => []}, {:item_requirement_ids => []}, :patient_id, :template_report_id ]})
	end


end