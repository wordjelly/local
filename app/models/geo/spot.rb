require 'elasticsearch/persistence/model'
class Geo::Spot

	## write the routes
	## integrate with form, 
	## for the location concern

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::BarcodeConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern

	index_name "pathofast-geo-spots"
	document_type "geo/spot"

	attribute :location_id, String
	validates_presence_of :location_id

	attribute :tags, Float

	attribute :name, Float
	validates_presence_of :name

    mapping do
	    indexes :name, type: 'keyword', fields: {
	      	:raw => {
	      		:type => "text",
	      		:analyzer => "nGram_analyzer",
	      		:search_analyzer => "whitespace_analyzer"
	      	}
	    },
	    copy_to: "search_all"

	    indexes :tags, type: 'keyword', copy_to: "search_all"

	    indexes :location_id, type: 'keyword', copy_to: "search_all"
	end
	
	## so these are the location and sub location attributes
	## one location should be automatically created?
	## from the organization address?
	def self.permitted_params
		base = [
				:id,
				{:spot => 
					[
						:latitude,
						:longitude,	
						:address
					]
				}
			]
		if defined? @permitted_params
			base[1][:spot] << @permitted_params
			base[1][:spot].flatten!
		end
		base
	end

	def assign_id_from_name
		if self.id.blank?			
			self.name = self.created_by_user.organization.name.to_s + "-" + self.class.name.to_s + "-" + BSON::ObjectId.new.to_s
			self.id = self.name
		end
	end

end