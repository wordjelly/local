## THIS CONCERN HAS TO BE THE LAST INCLUDED CONCERN
## IN THE CONCERNS OF ANY MODEL.
module Concerns::MissingMethodConcern

	extend ActiveSupport::Concern

	included do 

		before_save do |document|
			document.nullify_nil_attributes
		end

		def new_record?
			begin
				self.class.find(self.id.to_s)
				false
			rescue
				true
			end
		end

		def object_exists?(obj_class,id)
			begin
				obj_class.constantize.find(id)
			rescue
				false
			end
		end

		def nullify_nil_attributes
			self.attributes.keys.each do |attribute|
				self.send(attribute.to_s + "=",nil) if self.send(attribute).blank?
			end
		end
	end

	module ClassMethods

	    def additional_attributes_for_json
	    	if defined? @json_attributes
	    		@json_attributes
	    	else
	    		[]
	    	end
	    end
		
	end

end