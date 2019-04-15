class BaseController < ApplicationController

	before_filter :get_action_permissions
	before_filter :get_user_group_permissions
	before_filter :proceed_to_action?
	before_filter :set_model, :only => [:show,:update,:destroy,:edit]

	def new
		session.delete("@#{get_resource_name}".to_sym)
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

		if session[:user]
			query[:bool][:must] << {terms: {owner_ids: session[:user].organization_ids}}
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
		if session[:user]
			if instance.respond_to? :organization_ids
				instance.organization_ids << session[:user].organization_id
			end
		end
		instance.save
		session[get_resource_name.to_sym] = instance
	end

	## 

	def update
		instance_variable_get("@#{get_resource_name}").send("merge",get_model_params)
		instance_variable_get("@#{get_resource_name}").send("save")
	end

	def set_model

		query = {
			query: {
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
		}

		if session[:user]
			query[:bool][:must] << {terms: {owner_ids: session[:user].organization_ids}}
		end

		results = get_resource_class.search(query)

		if results.response.hits.hits.size > 0
			obj = get_resource_class.new(result.response.hits.hits[0]["_source"])
			obj.id = result.response.hits.hits[0]["_id"]
			obj.run_callbacks(:find)
			instance_variable_set("@#{get_resource_name}",obj)
		else

		end

	end

	def proceed_to_action?
		@attributes_to_exclude = []
		if @action_permissions["requires_authentication"] == "yes"
			authenticate(strict: true)
			authorize
		elsif @action_permissions["requires_authentication"] == "optional"
			authenticate(strict: false)
			authorize
		elsif @action_permissions["requires_authentication"] == "no"
		end
	end

	###############################################################
	##
	##
	## AUTHENTICATE ACTIONS
	##
	##
	###############################################################
	def authenticate(args)
		## if a username and password has been provided.
		if (params[:mobile_number] && params[:password])
			u = User.find(params[:mobile_number])
			begin
				u.sign_in(params[:password])
				session[:user] = u
			rescue
				## fail.
			end
		elsif (params[:mobile_number] && params[:access_token])
			u = User.find(mobile_number)
			if u.compare_and_refresh_access_token(params[:access_token])
				session[:user] = u	
			else
				## fail.
			end
		else
			if session[:user].blank?
				## fail
			else
				## nothing.
			end
		end
	end

	def authorize
		!@user_group_permissions.blank?
	end


	#def is_authorized?
		
	#end

	def get_action_permissions
		@action_permissions = $permissions["controllers"][controller_name]["actions"].select{|c| c["action_name"] == action_name }[0]
		@action_permissions
	end

	def get_user_group_permissions
		@user_group_permissions = nil
		if session[:user] 
			perms = @action_permissions["groups"].select{|c|
				c["group_name"] == session[:user].group
			}
			@user_group_permissions = perms[0] unless perms.blank?
		end
	end


	def get_user
		session[:user]
	end

	def get_resource_name
		controller_name.singularize
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