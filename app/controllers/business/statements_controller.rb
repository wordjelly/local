class Business::StatementsController  < ApplicationController

	include Concerns::BaseControllerConcern

	skip_before_action :set_model

	def edit
		instance = get_resource_class.new(get_model_params)
		instance.run_callbacks(:find)
		instance_variable_set("@#{get_resource_name}",instance)
	end

	def update
		statement = get_resource_class.new(get_model_params)

		statement.generate_statement(current_user)
		
		instance_variable_set("@#{get_resource_name}",statement)
		set_errors_instance_variable(instance_variable_get("@#{get_resource_name}"))
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
					render :json => {get_resource_name.to_sym => instance.as_json(methods: instance.class.additional_attributes_for_json)}, :status => 201
				else
					render :json => {get_resource_name.to_sym => instance, errors: @errors.full_messages.to_s}, :status => 404
				end
			end
		end
	end

	def create
		@statement = get_resource_class.new(get_model_params)

		@statement.generate_statement(current_user)
		
		@errors = @statement.errors

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
					render :json => {get_resource_name.to_sym => instance.as_json(methods: instance.class.additional_attributes_for_json)}, :status => 201
				else
					render :json => {get_resource_name.to_sym => instance, errors: @errors.full_messages.to_s}, :status => 404
				end
			end
		end
	end
	

end