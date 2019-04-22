class BaseController < ApplicationController

	respond_to :js, :html, :json
	before_action :get_action_permissions
	before_action :get_user_group_permissions
	before_action :proceed_to_action?
	before_action :set_model, :only => [:show,:update,:destroy,:edit]

	def new
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

		if user = get_user
			query[:bool][:must] << {terms: {owner_ids: user.organization_ids}}
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
		if user = get_user
			if instance.respond_to? :organization_ids
				instance.organization_ids << user.organization_id
			end
		end
		instance.save
		instance_variable_set("@#{get_resource_name}",instance)
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

		if user = get_user
			query[:bool][:must] << {terms: {owner_ids: user.organization_ids}}
		end

		results = get_resource_class.search({query: query})

		if results.response.hits.hits.size > 0
			obj = get_resource_class.new(results.response.hits.hits[0]["_source"])
			obj.id = results.response.hits.hits[0]["_id"]
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
		if (params[:id] && params[:password])
			u = User.find(params[:id])
			begin
				u.sign_in_admin(params[:password])
				session[:user] = u
			rescue => e
				puts e.to_s
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

	## let me just get sign up working.
	## then sign in and forgot, resend.
	## 

	def authorize
		!@user_group_permissions.blank?
	end


	#def is_authorized?
		
	#end

	def get_action_permissions
		#puts "the action name is:"
		#puts action_name.to_s
		@action_permissions = $permissions["controllers"][controller_name]["actions"].select{|c| c["action_name"] == action_name }[0]
		@action_permissions
		#puts "permissions--------"
		#puts $permissions.to_s
		#puts "controller name----------"
		#puts controller_name.to_s
		#puts "action permissions set as:"
		#puts @action_permissions
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
		if session[:user]
			u = User.find(session[:user].id.to_s)
			session[:user] = u
			u
		else
			nil
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
		unless get_user.blank?
			## there is an authenticated user.
			if @user_group_permissions
				## if it has some permissions.
				## keep only those parameters which are not unpermitted.
				unless @user_group_permissions.unpermitted_parameters.blank?
					return attributes.keep_if{|k,v|  !@user_group_permissions.unpermitted_parameters.include? k}
				end
			end
		else
			## no user has been authenticated.
			## if there are some optional parameters, allow only these.
			if @action_permissions["parameters_allowed_on_non_authenticated_user"]
				return attributes.keep_if{|k,v| @action_permissions["parameters_allowed_on_non_authenticated_user"].include? k}
			end
		end
		return attributes
	end

	def permitted_params
		params.permit(get_resource_class.permitted_params)
	end



end