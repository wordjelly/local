require 'elasticsearch/persistence/model'
class Tag

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-tags"

	attribute :name, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validates_presence_of :name

	EMPLOYEE_TAG = "employee"
	COLLECTION_TAG = "collection"
	TAG_TYPES = [EMPLOYEE_TAG,COLLECTION_TAG]

	attribute :tag_type, String
	validates_presence_of :tag_type

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

	def self.permitted_params
		[:id , {:tag => [:name, :tag_type]}]
	end

	
	
end