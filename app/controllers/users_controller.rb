class UsersController < BaseController

	def create
		super
		respond_to do |format|
			format.html do 
				redirect_to sign_in_options_users_path(user: @user.attributes.except(:password))
			end
			format.json do 
				render :json => {user: @user.to_json}
			end
		end
	end

	def sign_in_options
		instance = get_resource_class.new(get_model_params)
		instance_variable_set("@#{get_resource_name}",instance)
	end
end