module Concerns::BaseControllerConcern

    extend ActiveSupport::Concern

    def not_found(error = 'Not Found')
	   raise ActionController::RoutingError.new(error)
	end

    included do
        respond_to :js, :html, :json
        before_action :pretty_print_params
        before_action :get_action_permissions
        ## here you have to modify permissions ?
        ## or what ?
        if $permissions["controllers"][controller_name].blank?
        	raise ActionController::RoutingError.new("Please set permissions for this controller")
        end

        ## ill have to put that into the configuration for 
        ## token authentication.
    
        @tconditions = {:only => $permissions["controllers"][controller_name]["actions"].select{|c| c["requires_authentication"] != "no"}.map{|c| c["action_name"].to_sym}}
        puts "going to devise concern"
    	
    	include Auth::Concerns::DeviseConcern
    	puts "going to token concern"
    	include Auth::Concerns::TokenConcern
    	puts "going to do before request."
    	before_action :do_before_request, @tconditions
    	puts "crossed do before request"
    	before_action :set_organization_from_header
		before_action :set_model, :only => [:show,:update,:destroy,:edit]
		
    end

    def pretty_print_params
    	pp params.to_unsafe_h
    end

    def set_organization_from_header
    	puts "came to set organization from header"
    	puts "current user: #{current_user}"
    	current_user.set_organization_from_header(request.headers) unless current_user.blank?
    end

    ## now we go for the versioning.
    def new
    	#puts "teh get model params are:"
    	#puts get_model_params.to_s
		instance = get_resource_class.new(get_model_params)
		instance.run_callbacks(:find)
		instance_variable_set("@#{get_resource_name}",instance)
	end

	def show
		respond_to do |format|
			format.html do 
				render :show
			end
			format.json do 
				render :json => {get_resource_name.to_sym => instance_variable_get("@#{get_resource_name}")}
			end
		end
	end

	def edit
		## just rendering form.
	end

	def index

		query = {
			bool: {
				must: [
					{
						match_all: {}
					}
				],
				should: [
					{
						term: {
							public: 1
						}
					}
				]
			}
		}

		## uses the params sent into the action to make a query.
		## so simple filters can be automatically added to the query by just adding them to the url.
		q = get_model_params
		q.keys.each do |key|
			unless q[key].blank?
				if q[key].is_a? Array
					query[:bool][:must] << {
						terms: {
							key.to_sym => q[key]
						}
					}
				else 
					query[:bool][:must] << {
						term: {
							key.to_sym => q[key]
						}
					}
				end
			end
		end

		if current_user
			if current_user.belongs_to_organization?
				query[:bool][:should] << {
					terms: {
						owner_ids: current_user.organization.all_organizations
					}
				}
			else
				query[:bool][:should] << {
					term: {
						owner_ids: current_user.id.to_s
					}
				}
			end
		end

		#puts "index action final query is--------------->"
		#puts JSON.pretty_generate(query)

		#modulate the query if reauired
		aggs = nil
		size = 10
=begin
		if get_resource_class.respond_to? :index_controller_action
			response = get_resource_class.index_controller_action(query,params,current_user)
			query = response[:query]
			aggs = response[:aggs] unless response[:aggs].blank?
			size = response[:size] unless response[:size].blank?
		end
=end
		final_query_hash = 
		{
			size: size,
			sort: {
				"updated_at".to_sym => {
					"order".to_sym => "desc"
				}
			},
			query: query
		}
		final_query_hash[:aggs] = aggs unless aggs.blank?

		#puts "final query hash is:"
		#puts final_query_hash[:aggs]

		results = get_resource_class.search(
			final_query_hash
		)

		if results.response.hits.hits.size > 0
			objects = results.response.hits.hits.map{|c|
				obj = get_resource_class.new(c["_source"])
				obj.id = c["_id"]
				obj.run_callbacks(:find) do 
					obj.apply_current_user(current_user)
				end
				obj
			}
			instance_variable_set("@#{get_resource_name.pluralize}",objects)
		else
			#puts "no results, we parse the aggregations."
			#if get_resource_class.respond_to? :parse_index_controller_aggregation
			#	objects = get_resource_class.parse_index_controller_aggregation(results.response)
			#	instance_variable_set("@#{get_resource_name.pluralize}",objects)
			#else
			instance_variable_set("@#{get_resource_name.pluralize}",[])
			#end
		end

		respond_to do |format|
			## lets see if it works with organizations.
			format.json do 
				render :json => {get_resource_name.pluralize.to_sym => objects}
			end

			format.html do 
				render :index
			end
		end

	end
	

	def create
		instance = get_resource_class.new(get_model_params.except(@attributes_to_exclude))
		## this is an attribute accessor.	
		##puts "is there a current user?"
		##puts current_user.to_s
		instance.created_by_user = current_user if current_user
			
		## this is an actual attribute.
		## useful to know who created the document.
		## it is defined in owners concern.
		instance.created_by_user_id = current_user.id.to_s if current_user
		## do the name id setting here itself.
		## this assigns the id from the name if the name is present.
		## if the name is not present, will do nothing.
		## for any date, it should default to nil if blank.
		## 
		#instance.arrived_on = nil
		#instance.send("assign_id_from_name") if instance.respond_to? :assign_id_from_name

		if instance.respond_to? :versions
			instance.verified_by_user_ids = [current_user.id.to_s]
		end
		
		
		if instance.respond_to? :versions
			## so this is the default behaviour.
			## now how to incorporate a challenge to have it verified.
			## i can specify a verification parameter
			## that is if you are accepting a version, then you have to provide a value for any number of custom parameters,  parameter, and it can be evaluated in the verified by users thign.
			v = Version.new(attributes_string: JSON.generate(get_model_params.merge(:verified_by_user_ids => [current_user.id.to_s], :rejected_by_user_ids => [])))
			v.assign_control_doc_number
			instance.versions.push(v)
		end

		# so how to transfer from one item group --> a local item group
		# so the local_item_group -> can there be multiple ?
		# 

		# okay so the permitted parameters.
		## this has to be a global setting
		## like in test, we have to be able to disable it in the
		## while testing.
		## can this be done as a configuration.
		## what about chekcing if it is a test env.?
		#if Rails.env.test?
		puts " ------------ CAME TO SAVE THE RECORD -------------- "
		if Rails.env.test? || Rails.env.development?
			if ENV["CREATE_UNIQUE_RECORDS"].blank?
				instance.save(op_type: 'create')
			elsif ENV["CREATE_UNIQUE_RECORDS"] == "no"
				instance.save
			end
		else
			instance.save(op_type: 'create')
		end

		set_errors_instance_variable(instance)
		
		instance.run_callbacks(:find)

		instance_variable_set("@#{get_resource_name}",instance)

		#puts "the instance is:"
		#puts instance.attributes.to_s

		respond_to do |format|
			format.html do 
				if @errors.full_messages.empty?
					render :show
				else
					render :new
				end
			end

			## we can call instance.as_json(methods: instance.)
			format.json do 
				if @errors.full_messages.empty?
					#render :json => {get_resource_name.to_sym => instance}, :status => 201
					#build_complex_industries
					render :json => {get_resource_name.to_sym => instance.as_json(methods: instance.class.additional_attributes_for_json)}, :status => 201
				else
					render :json => {get_resource_name.to_sym => instance, errors: @errors.full_messages.to_s}, :status => 404
				end
			end
		end
	end

	## here we can override the as_json
	## instance.as_json()

	def update
		

		## awesome print the params
		##params_json = JSON.pretty_generate(params)
		##puts params_json
		#para = JSON.parse(params_json)
		#ap para

		if instance_variable_get("@#{get_resource_name}").respond_to? :versions
			
			if ((instance_variable_get("@#{get_resource_name}").verified_user_ids_changed?(get_model_params[:verified_by_user_ids])) || (instance_variable_get("@#{get_resource_name}").rejected_user_ids_changed?(get_model_params[:rejected_by_user_ids])))

				## only thing which remains is seeing if it changed by anything other than the current user
				## because that is not allowed.

				v = Version.new(attributes_string: JSON.generate(instance_variable_get("@#{get_resource_name}").attributes.merge(verified_by_user_ids: get_model_params[:verified_by_user_ids], rejected_by_user_ids: get_model_params[:rejected_by_user_ids])))

				v.assign_control_doc_number

				## check the password parameters.
				## this can be done at this stage.
				## if you are passing in a verified.
				## we can have that as an attribute accessor on version, all the model params.
				## so if you are saying yes to verified.
				## it can evaluate the incoming hash against a previous version.
				## did anything else change ?
				## that's pretty straightforward to implement.
				## like did a given set of parameters stay the same.
				## we can call them truth parameters.
				## which will 
				unless v.tampering?(instance_variable_get("@#{get_resource_name}").non_tamperables,instance_variable_get("@#{get_resource_name}").versions[-1],get_model_params,instance_variable_get("@#{get_resource_name}").class.name)

					instance_variable_get("@#{get_resource_name}").send("versions").push(v)

				end

			else

				if instance_variable_get("@#{get_resource_name}").verified_or_rejected?
					## so any further changes are considered to be accepted by the creator.
					v = Version.new(attributes_string: JSON.generate(get_model_params.merge(:verified_by_user_ids => [current_user.id.to_s], rejected_by_user_ids => [])))

					v.assign_control_doc_number

					instance_variable_get("@#{get_resource_name}").send("versions").push(v)
				end
			end		
		else

			t1 = Time.now.to_f
			assign_incoming_attributes
			t2 = Time.now.to_f
			puts "assign attributes takes---------------------------------------------------------------->: #{(t2 - t1).in_milliseconds}"

		end

		## so after find does not load the created_by_user
		## what about a current_user ?
		if current_user
			instance_variable_get("@#{get_resource_name}").send("created_by_user=",current_user) 
		end
		
	
		#puts " ---------- ENDING HERE ---------------- "

		t1 = Time.now
		instance_variable_get("@#{get_resource_name}").send("save")
		set_errors_instance_variable(instance_variable_get("@#{get_resource_name}"))
		t2 = Time.now
		puts "save in update takes --------------------------------------------------------------------> #{(t2 - t1).in_milliseconds}"
		set_alert_instance_variable(instance_variable_get("@#{get_resource_name}"))
		instance_variable_get("@#{get_resource_name}").send("run_callbacks","find".to_sym)

		#puts "instance variable get yields."
		#puts @organization.users_pending_approval.to_s
		#puts instance_variable_get("@#{get_resource_name}").to_json
		## and this user does not have a current app id.
		## so its hanging, internally on the to_json call for the user.
		## that is failing internally from auth.
		## not from here.
		## its because you are calling to_json.

		respond_to do |format|
			format.html do 
				if @errors.full_messages.empty?
					render :show
				else
					render :edit
				end
			end
			format.json do 
				if @errors.full_messages.empty?
					render :json => {get_resource_name.to_sym => instance_variable_get("@#{get_resource_name}")}.to_json, status: 204
				else
					#puts "errors are:"
					#puts @errors.full_messages.to_s
					#render json: {hello: "world"}, status: 200
					#puts "got errors"
					#exit(1)	
					render :json => {get_resource_name.to_sym => instance_variable_get("@#{get_resource_name}"), errors: @errors}.to_json, status: 404
				end
			end
		end
	end


	def assign_incoming_attributes 		
		get_model_params.assign_attributes(instance_variable_get("@#{get_resource_name}"))
	end

	def set_model
		
		query = {
			bool: {
				must: [
					{
						ids: {
							values: [params[:id]]
						}
					},
					{
						bool: {
							minimum_should_match: 1,
							should: [
								{
									term: {
										public: 1
									}
								}
							]
						}
					}
				]
			}
		}

		## this is added as a must clause.
		## but here only we have to add that as an optional.
		query = add_authorization_clause(query) if (@action_permissions["requires_authorization"] == "yes")
		
		## so only its own user has been added.
		#puts "query after adding authorization clause is:"
		#puts JSON.pretty_generate(query)

		#puts "resource class is:"
		#puts get_resource_class.to_s
		t1 = Time.now
		results = get_resource_class.search({size: 1, query: query})
		t2 = Time.now
		puts "total time taken to do the query: #{(t2 - t1).in_milliseconds}"
		if results.response.hits.hits.size > 0
			t1 = Time.now
			obj = get_resource_class.new(results.response.hits.hits[0]["_source"])
			t2 = Time.now
			puts "total time taken to initialize the object: #{(t2 - t1).in_milliseconds}"
			obj.id = results.response.hits.hits[0]["_id"]
			#obj = get_resource_class.find(results.response.hits.hits[0]["_id"])
			obj.run_callbacks(:find) do 
				obj.apply_current_user(current_user)
			end
			obj.newly_added = false
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
	## this is overriden in the Orders Controller.
	## as more than one organization should be allowed to edit 
	## it if there is outsourcing.
	## so here we check if any report has been owned by this organziation.
	## @return[Hash] : the updated query, to include only those resources, that have 
	def add_authorization_clause(query)
		#puts "is there a current user?"
		#puts current_user.to_s
		#puts "the query currently is:"
		#puts JSON.pretty_generate(query)
		if current_user
			## check if the current user's id has been mntioned in the owner_ids of the resource.
			query[:bool][:must][1][:bool][:should] <<
			{		
				term: {
					owner_ids: current_user.id.to_s
				}	
			}

			## so address is already provided by location.
			## but that is a changable location
			
			## this bug was hiding here.
			## puts "the current user organization is:"
			## puts current_user.organization.to_s
			unless current_user.organization.blank?
				#if current_user.verified_as_belonging_to_organization.blank?
				#	puts "user is not verified as belonging to the given organization, so we cannot use its organization id to check for ownership"
					##not_found("user has not been verified as belonging to his claimed organization id , and this needs authorization #{controller_name}##{action_name}")
				#else
				query[:bool][:must][1][:bool][:should] << {terms: {owner_ids: current_user.organization.all_organizations }}
				#end 
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
		#puts "came to get action permissions."
		@action_permissions = $permissions["controllers"][controller_name]["actions"].select{|c| c["action_name"] == action_name }[0]
	
		not_found("Please define permissions for : #{controller_name}##{action_name}") if @action_permissions.blank?

		#puts "got action permissions as:"
		#puts @action_permissions.to_s
		
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
		#puts "The controller path is:"
		#puts controller_path.to_s
		#puts "the symbol chosen is:#{controller_path.classify.demodulize.underscore.downcase.to_sym}"
		attributes = permitted_params.fetch(controller_path.classify.demodulize.underscore.downcase.to_sym,{})
		#puts "the attributes become:"
		#puts attributes.to_s
		if current_user
			#puts "there is a current user."
			if @user_group_permissions
				#puts "there are user group permissions"
				unless @user_group_permissions.unpermitted_parameters.blank?
					return attributes.keep_if{|k,v|  !@user_group_permissions.unpermitted_parameters.include? k}
				end
			end
		else
			#puts "there is no current user"
			if @action_permissions["parameters_allowed_on_non_authenticated_user"]
				return attributes.keep_if{|k,v| @action_permissions["parameters_allowed_on_non_authenticated_user"].include? k}
			end
		end
		#puts "attributes returned"
		#puts JSON.pretty_generate(attributes)

		#deep_clean_arrays(attributes)
=begin
		attributes = {
			:k => 2,
			:hello => ["",""],
			:bye => {
				:hello => ["",""]
			},
			:three => {
				:hello => [
					{
						:hello => ["",""]
					}
				]
			}

		}
=end
		#puts JSON.pretty_generate(attributes.deep_clean_arrays)

		return attributes.deep_clean_arrays
	end

	

	def permitted_params
		#puts "the resource class is: #{get_resource_class}"
		#puts "the params defined in the resource ---------->"
		#puts get_resource_class.permitted_params.to_s
		k = params.permit(get_resource_class.permitted_params).to_h
		#puts "the permitted params are:"
		#puts k.to_s
		k
	end


end