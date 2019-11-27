module Concerns::BackgroundJobConcern
	
	extend ActiveSupport::Concern
	
	included do 

	end

	## called from jobs/schedule_job.rb
	## override in respective models.
	## by default expects a method name to be passed in, and calsl that method.
	def do_background_job(method_name)
		self.send(method_name) if self.respond_to? method_name.to_s
	end

end