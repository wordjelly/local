class PatientsController  < UsersController

	include Concerns::BaseControllerConcern

	## now everything comes from the base controller concern.
=begin
	respond_to :html, :json, :js

	def new
		@patient = Patient.new
	end

	def edit
		@patient = Patient.find(params[:id])
	end

	def create
		@patient = Patient.new(permitted_params["patient"])
		response = @patient.save
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def update
		@patient = Patient.find(params[:id])
		
		@patient.update_attributes(permitted_params["patient"])
		
		respond_to do |format|
			format.html do 
				render "show"
			end
		end
	end

	def destroy
	end

	def show
		@patient = Patient.find(params[:id])
		
	end

	def index
		@patients = Patient.all
	end

	
	def permitted_params
		params.permit(:id , {:patient => [:first_name,:last_name,:date_of_birth,:email, :mobile_number, :area, :allergies, :anticoagulants, :diabetic, :asthmatic, :heart_problems]})
	end
=end

end