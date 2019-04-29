class HomeController < ApplicationController
	
	respond_to :html

	def index
		User.delete_all
	end	

end