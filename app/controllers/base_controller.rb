class BaseController < ApplicationController

	def new
		instance = get_resource_class.new(get_model_params)
		instance_variable_set("@#{controller_name}",instance)
	end

	def show

	end

	def edit
	end

	def index
	end

	def create
	end

	def update
	end

	def set_model
		## so this can work.
		## this is done before show, update and destroy
		## 
	end

	def proceed_to_action?
		if @action_permissions["requires_authentication"] == true
			if is_authenticated?
				
				## attributes to exclude are set here.
				## and used in the permitted params.
				## 
			else

			end
		else
			true
		end
	end

	def user_permitted_on_action?
		## a user may belong to multiple groups
		## whichever is the first group that is permitted
		## on the action is passed.
	end

	def get_action_permissions
		@action_permissions = $permissions["controllers"][controller_name]["actions"].select{|c| c["action_name"] == action_name }
		@action_permissions
	end

	def is_authenticated?
		!get_user.blank?
	end

	def get_user
		session[:user]
	end

	def get_resource_class
		controller_path.classify.constantize
	end

	def get_model_params
		permitted_params.fetch(controller_path.classify.downcase.to_sym,{})
	end

	def permitted_params
		params.permit(get_resource_class.permitted_params)
	end

end