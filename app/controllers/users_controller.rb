class UsersController < BaseController
	def proceed_to_action?
		@attributes_to_exclude = []
		if @action_permissions["requires_authentication"] == true
			if session[:user]
				if session[:user].confirmed?
					@attributes_to_exclude = ["password","password_confirmation"]
				else
					
				end
				true
			else
				false
			end
		else
			true
		end
	end

	def sign_in_options
		
	end
end