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

		@errors = instance.errors
		
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

		## owner id clause is added only if 
		## this should have worked.
		## i need to see the organization owner ids.
		## and the current user organization id.
		## the owner id was not added before save.
		## first have to see why that is not working.

		if current_user
			query[:bool][:must] << {term: {owner_ids: current_user.organization_id}} unless current_user.organization_id.blank?
		end

		puts "the query sent for set_model is:"
		puts JSON.pretty_generate(query)

		puts "the resource class is: #{get_resource_class}"

		results = get_resource_class.search({query: query})

		if results.response.hits.hits.size > 0
			obj = get_resource_class.find(results.response.hits.hits[0]["_id"])
			obj.run_callbacks(:find)
			## loads the images as an instance variable.
			if obj.images.size > 0
				instance_variable_set("@images",obj.images)
			end
			instance_variable_set("@#{get_resource_name}",obj)
		else
		end
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

	## let me just get sign up working.
	## then sign in and forgot, resend.
	## 

	def authorize
		!@user_group_permissions.blank?
	end


	#def is_authorized?
		
	#end

	def get_action_permissions
		
		@action_permissions = $permissions["controllers"][controller_name]["actions"].select{|c| c["action_name"] == action_name }[0]
	
		not_found("Please define permissions for : #{controller_name}##{action_name}") if @action_permissions.blank?

		if @action_permissions["requires_authentication"] == "yes"
			#TCONDITIONS = {:only => action_name.to_sym}
			#what about invoking some code in the beginning
			#of the controller.
			#defining this from the actions.
			#
		end
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