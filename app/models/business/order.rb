require 'elasticsearch/persistence/model'
class Business::Order

	include Elasticsearch::Persistence::Model
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
	index_name "pathofast-business-orders"
	document_type "business/order"
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::SearchOptionsConcern
	include Concerns::FormConcern

	
	include Concerns::Schedule::QueryBuilderConcern
	include Concerns::OrderConcern
	include Concerns::PdfConcern

	before_save do |document|
		document.cascade_id_generation(nil)
	end

	## we add a hidden field called name.
	def customizations(root)
		customizations = {}
		if self.name.blank?
			customizations["name"] = '<input type="hidden" name="order[name]" value="' + BSON::ObjectId.new.to_s + '" />'
		else
			'<input type="hidden" name="order[name]" value="' + self.name.to_s + '" />'
		end
		customizations
	end

	## overriden this method to assign the name, as a bson id.
	## since the organization will already be fed in automatically
	def assign_id_from_name(organization_id)
		self.name ||= BSON::ObjectId.new.to_s
		if self.id.blank?
			unless self.name.blank?
				if organization_id.blank?	
					## this will happen for organization.		
					self.id = (BSON::ObjectId.new.to_s + "-" + self.name)
				else
					self.id = organization_id + "-" + self.name
				end
			end
		end
	end

end