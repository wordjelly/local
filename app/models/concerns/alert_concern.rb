module Concerns::AlertConcern

	extend ActiveSupport::Concern

  	included do

  		attr_accessor :alert

  		after_find do |document|
  			document.set_alert
  		end

  	end

  	## override this method to set an alert message.
  	def set_alert

  	end

end	