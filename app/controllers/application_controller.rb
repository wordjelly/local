class ApplicationController < ActionController::Base

  layout 'application'
  respond_to :html,:js,:json
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :set_image_instance_variable


  def set_image_instance_variable
    ## $u is the UUID instance generated in the initializer
  	@image = Image.new(:id => $u.generate)
  end

   	protected

  	def devise_parameter_sanitizer
      if resource_class == User
        User::ParameterSanitizer.new(User, :user, params)
      else
        super # Use the default one
      end
  	end

end
