class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :set_image_instance_variable


  def set_image_instance_variable
    ## $u is the UUID instance generated in the initializer
  	@image = Image.new(:id => $u.generate)
  end

end
