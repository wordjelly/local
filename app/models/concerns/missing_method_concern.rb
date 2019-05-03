module Concerns::MissingMethodConcern

	extend ActiveSupport::Concern

	included do 

		def new_record?
			begin
				self.class.find(self.id.to_s)
				false
			rescue
				true
			end
		end

	end

end