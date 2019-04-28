module Concerns::BaseControllerConcern

    extend ActiveSupport::Concern

    def not_found(error = 'Not Found')
	   raise ActionController::RoutingError.new(error)
	end

    included do
        respond_to :js, :html, :json
        #puts "actions needing authentication"
        #puts $permissions["controllers"][controller_name]["actions"].to_s
        #puts $permissions["controllers"][controller_name]["actions"].select{|c| c["requires_authentication"] != "no"}
        
        #puts " ---------------------------------------------- "
        @tconditions = {:only => $permissions["controllers"][controller_name]["actions"].select{|c| c["requires_authentication"] != "no"}.map{|c| c["action_name"].to_sym}}
		before_action :get_action_permissions
    	include Auth::Concerns::DeviseConcern
    	include Auth::Concerns::TokenConcern
		before_action :set_model, :only => [:show,:update,:destroy,:edit]
    end

    def new
    	#puts "teh get model params are:"
    	#puts get_model_params.to_s
		instance = get_resource_class.new(get_model_params)
		instance_variable_set("@#{get_resource_name}",instance)
	end

	def show
		## this just does set model and then renders show.
	end

	def edit
		## same here.
	end

	def index
		query = {
			query: {
				bool: {
					must: [
						{
							match_all: {}
						}
					]
				}
			}
		}

		if current_user
			query[:bool][:must] << {terms: {owner_ids: current_user.organization_id}}
		end

		results = get_resource_class.search(query)

		if results.response.hits.hits.size > 0
			objects = results.response.hits.hits.map{|c|
				obj = get_resource_class.new(c["_source"])
				obj.id = c["_id"]
				obj.run_callbacks(:find)
				obj
			}
			instance_variable_set("#{get_resource_name.pluralize}",objects)
		else
			instance_variable_set("#{get_resource_name.pluralize}",[])
		end
	end
	

	def create

		instance = get_resource_class.new(get_model_params.except(@attributes_to_exclude))
			
		instance.created_by_user = current_user if current_user
		
		instance.save

		set_errors_instance_variable(instance)
		
		instance_variable_set("@#{get_resource_name}",instance)

		respond_to do |format|
			format.html do 
				if @errors.full_messages.empty?
					render :show
				else
					render :new
				end
			end
			format.json do 
				if @errors.full_messages.empty?
					render :json => {get_resource_name.to_sym => instance.to_json}
				else

				end
			end
		end

	end

	def update
		instance_variable_get("@#{get_resource_name}").send("attributes=",instance_variable_get("@#{get_resource_name}").send("attributes").send("merge",get_model_params))
		instance_variable_get("@#{get_resource_name}").send("save")
		set_errors_instance_variable
		set_alert_instance_variable
	end

	def set_model
		query = {
			bool: {
				must: [
					{
						ids: {
							values: [params[:id]]
						}
					}
				]
			}
		}
		query = add_authorization_clause(query) (if @action_permissions["requires_authorization"] == "yes")
		results = get_resource_class.search({query: query})
		if results.response.hits.hits.size > 0
			obj = get_resource_class.find(results.response.hits.hits[0]["_id"])
			obj.run_callbacks(:find)
			set_images_instance_variable(obj)
			set_alert_instance_variable(obj)
			instance_variable_set("@#{get_resource_name}",obj)
		else
			not_found("no such model exists, or the current user does not have authorization to interact with the model")
		end
	end

	def set_images_instance_variable(obj)
		if obj.images.size > 0
			instance_variable_set("@images",obj.images)
		end
	end

	def set_alert_instance_variable(obj)
		if obj.respond_to? :alert
			instance_variable_set("@alert",obj.alert)
		end
	end

	def set_errors_instance_variable(obj)
		instance_variable_set("@errors",obj.errors)
	end

	## so we have to give the fallback as none on that action.
	## in some controllers.

	def proceed_to_action?
		@attributes_to_exclude = []
		if @action_permissions["requires_authentication"] == "no"
			authorize
		else
		end
	end

	###############################################################
	##
	##
	## AUTHENTICATE ACTIONS
	##
	##
	###############################################################
	## @param[Hash] query: the query for checking if the user has access to this resource, when the query enters this function, it is simply looking for a resource with the provided id. Eg: if you are in the OrganizationsController, it is looking for an organization with the provided id.
	## The def will first check if there is a current user, otherwise will throw an error.
	## then will check fi the current user even has an organization id, otherwise will throw an error
	## then checks if the current_user has been verified as belonging to that organization, otherwise, will throw an error.
	## last, if all above conditions have passed it will add the clause 
	## so now it will work out.
	## so if you create a patient,
	## lets say an organization creates a patient
	## we use the email/phone to search for an existing user
	## if the patient is not verified, then we add the user id, to it.
	## so prospective user id is added to patient.
	## if there is no user, id, then what happens?
	## simple callback
	## so the organization cannot create two patients with the same mobile number.
	## or email.
	## the patient id will be the organiztion_id_mobile_number of patient.
	## so that way we get it unique, without really trying and put a validates_presence_of mobile number.
	## so let's get on with the patient.
	## after sign_up -> check for patients, where verified == false, and mobile_number is same, will have 
	## we dont find an existing user -> we send a message to that mobile to sign up
	## they sign up.
	## 
	## @return[Hash] : the updated query, to include only those resources, that have 
	def add_authorization_clause(query)
		if current_user
			## check if the current user's id has been mntioned in the owner_ids of the resource.
			query[:bool][:must] <<
			{
				bool: {
					minimum_should_match: 1,
					should: [
						{
							term: {
								owner_ids: current_user.id.to_s
							}
						}
					]
				}
			}

			unless current_user.organization_id.blank?
				if current_user.verified_as_belonging_to_organization.blank?
					puts "user is not verified as belonging to the given organization, so we cannot use its organization id to check for ownership"
					##not_found("user has not been verified as belonging to his claimed organization id , and this needs authorization #{controller_name}##{action_name}")
				else
					query[:bool][:must][1][:should] << {term: {owner_ids: current_user.organization_id}}
				end 
			else
				puts "the user does not have an organization id, so we cannot check for ownership using it."
				#not_found("user does not have an organization_id, and authorization is necessary for this #{controller_name}##{action_name}")
			end
		else
			not_found("no current user, authorization is necessary for this #{controller_name}##{action_name}")
		end

		query
	end

	## let me just get sign up working.
	## then sign in and forgot, resend.
	def authorize
		!@user_group_permissions.blank?
	end


	#def is_authorized?
		
	#end

	def get_action_permissions
		
		@action_permissions = $permissions["controllers"][controller_name]["actions"].select{|c| c["action_name"] == action_name }[0]
	
		not_found("Please define permissions for : #{controller_name}##{action_name}") if @action_permissions.blank?

		
		@action_permissions

	end

	def get_user_group_permissions
		@user_group_permissions = nil
		if current_user
			perms = @action_permissions["groups"].select{|c|
				c["group_name"] == current_user.group
			}
			@user_group_permissions = perms[0] unless perms.blank?
		end
	end

	def get_resource_name
		controller_name.singularize
	end

	def get_resource_class
		controller_path.classify.constantize
	end

	def get_model_params
		attributes = permitted_params.fetch(controller_path.classify.downcase.to_sym,{})
		puts "the attributes become:"
		puts attributes.to_s
		if current_user
			puts "there is a current user."
			if @user_group_permissions
				puts "there are user group permissions"
				unless @user_group_permissions.unpermitted_parameters.blank?
					return attributes.keep_if{|k,v|  !@user_group_permissions.unpermitted_parameters.include? k}
				end
			end
		else
			puts "there is no current user"
			if @action_permissions["parameters_allowed_on_non_authenticated_user"]
				return attributes.keep_if{|k,v| @action_permissions["parameters_allowed_on_non_authenticated_user"].include? k}
			end
		end
		puts "returning attributes: #{attributes}"
		return attributes
	end

	def permitted_params
		params.permit(get_resource_class.permitted_params).to_h
	end


end