module Concerns::StepConcern

	extend ActiveSupport::Concern

	included do 

		## so it will have a corresponding view to manage it.
		attribute :steps, Array

	end

end