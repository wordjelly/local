class HomeController < ApplicationController
	
	respond_to :html

	def index
		User.delete_all
	end	

	# go over the entire api for sign in, sign up, forgot, resend
	# then add the api for organization, patient, and user confirmation of the patient
	# make that work with the UI , and give him the api docs.
	# that's the target for today.

end