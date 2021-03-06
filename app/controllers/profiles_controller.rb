class ProfilesController < Auth::ProfilesController
	
	respond_to :json,:html,:js

	def show
		## we can load credentials after_find.
		@profile_resource.m_client = self.m_client
		puts @profile_resource.attributes_to_return_with_profile
		respond_to do |format|
			format.html do 
				render :show
			end
			## so we can call as_json on it.
			## or we can 
			format.json do 
				render :json => {user: @profile_resource.attributes_to_return_with_profile}
			end
		end
	end

	def edit
		puts "came to edit action."
		puts "the resource params are"
		puts @resource_params.to_s
		## if you show it as an attribute then it will show everytime.
		## thats why i had done it like that.
		@profile_resource.attributes.merge!(@resource_params)
		puts "the organization id is:"
		puts @profile_resource.organization_member_organization_id
		puts "the employee role id is:"
		puts @profile_resource.organization_member_employee_role_id
	end

	def update

		## so we skip the regeneration at this point.
		@profile_resource.skip_authentication_token_regeneration = true
		
		check_for_update(@profile_resource)

		@profile_resource.assign_attributes(@resource_params)
		#exit(1)
		@profile_resource.m_client = self.m_client

		respond_to do |format|
  		  if @profile_resource.save
  		  	  #puts "the authentication token after doing the update"
  		  	  #puts @profile_resource.authentication_token
  		  	  #k = User.find(@profile_resource.id.to_s)
  		  	  #puts k.authentication_token
  		  	  
  		  	  flash[:notice] = "Success"
  		  	  ## it should not regenerate the token after this actually.
	  		  format.json {head :no_content}
	  		  format.html {redirect_to profile_path({:id => @profile_resource.id.to_s, :resource => @profile_resource.class.name.pluralize.downcase.to_s})}
  		  else
  		  	  flash[:notice] = @profile_resource.errors.full_messages
  		  	  format.json {render :json => @profile_resource.errors, :status => :unprocessable_entity}
  		  	  format.html {redirect_to profile_path({:id => @profile_resource.id.to_s, :resource => @profile_resource.class.name.pluralize.downcase.to_s})}
  		  end
  		end
	end

	## time to check for authorization.
	## or first i can make a patient's controller.
	## and see how to assign an order to it.
	## remember that the patient id, is what is going through
	## we can create a patient for the user also.
	## and use him throughout.
	## basically a given user is going to be linked to multiple patients.
	## who owns the patient ?
	## creating organization and once it has been verified, the
	## user itself.
	## the user's organization id, should be his own id.
	## do that on create.
	## 



	private
	def permitted_params
		if action_name.to_s == "credential_exists"
			params.require(:credential).permit(Devise.authentication_keys + [:resource])	
		else
			filters = []
		
	  		Auth.configuration.auth_resources.keys.each do |model|
	  			if current_signed_in_resource  
	  				
	  				## so this is an employee_role_id.
	  				## that is now permitted.
	  				permitted_arr = [:organization_id, :role, :first_name, :last_name, :date_of_birth, :sex, :address,:employee_role_id,{:organization_members => [:organization_id, :employee_role_id, :created_by_this_user, :_id]}, :organization_member_organization_id, :organization_member_employee_role_id]
	  				


	  				permitted_arr = permitted_arr.flatten.uniq
	  				filters << {model.downcase.to_sym => permitted_arr }
	  			end
	  		end
	  		
	  		## resource has to be a plural.
	  		## it also should have the user id.
	  		## and under that user should pass the required attribute
	  		## so an example of a request to update a user's organization_id would be:
	  		## {:resource => "users", :id => user.id, :user => {:organization_id => "test", :role => "test"}}
	  		filters << [:resource,:api_key,:current_app_id,:id,:unset_proxy]
	  		params.permit(filters)
		end

	end

end	