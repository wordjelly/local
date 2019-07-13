require 'elasticsearch/persistence/model'
class Geo::Location

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern

	index_name "pathofast-geo-locations"
	document_type "geo/location"

	attribute :name, String

	attribute :latitude, Float

	attribute :longitude, Float

	attribute :address, String, mapping: {type: 'keyword'}

	attribute :model_id, String, mapping: {type: 'keyword'}

	attribute :model_class, String, mapping: {type: 'keyword'}


    mapping do
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"
	end

	
	
	## so these are the location and sub location attributes
	## one location should be automatically created?
	## from the organization address?
	def self.permitted_params
		base = [
				:id,
				{:location => 
					[
						:latitude,
						:longitude,	
						:address
					]
				}
			]
		if defined? @permitted_params
			base[1][:location] << @permitted_params
			base[1][:location].flatten!
		end
		base
	end

	def assign_id_from_name
		puts "Came to assign id from name."
		puts "why is this not working?"
		if self.id.blank?			
			self.name = self.class.name.to_s + "-" + BSON::ObjectId.new.to_s
			self.id = self.name
		end
	end

	def organization_users_are_enrolled_with_organization
		## skip if there is a model id and model class
		unless (self.model_id.blank?)
			## let this be.
		else
			if !self.created_by_user.has_organization?
				self.errors.add(:created_by_user,"you have not yet been verified as belonging to this organization")
			end
		end
	end

	def add_owner_ids
		if self.model_class == "Organization"
			self.owner_ids << [self.created_by_user.id.to_s, self.model_id.to_s]
		else
			if self.owner_ids.blank?
				unless self.created_by_user.blank?
					## in case the user is creating an organiztion,
					## it will not have an organization id itself.
					## since the organiztion has not yet even been created
					## that's why we started the system of adding the creating users id
					## to the owner ids of any document it creates. 
					## this part will change a bit.
					self.owner_ids = [self.created_by_user.id.to_s]
					unless self.created_by_user.organization.blank?
						
						self.owner_ids << [self.created_by_user.organization.id.to_s]
						self.currently_held_by_organization = created_by_user.organization.id.to_s
						
					end
				end
				## if the document is an organization, its own id 
				## is added as an owner
				## because when users belonging to this organization
				## try to access it, they will be using their organization id 
				## in the authorization query.
				## okay this is understandable.
				if self.class.name == "Organization"
					if self.owner_ids.blank?
						self.owner_ids << self.id.to_s
					end
				end
			end
		end
		self.owner_ids.flatten!
	end

	

end