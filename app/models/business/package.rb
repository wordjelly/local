require 'elasticsearch/persistence/model'

class Business::Package
	
	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern

	index_name "pathofast-business-packages"
	document_type "business/package"

	attribute :name, String, mapping: {type: 'keyword'}
	attr_accessor :report_name
	attribute :report_ids, Array, mapping: {type: 'keyword'}
	attribute :base_price, Float
	attribute :discounted_price, Float
	attribute :valid_till, Date

	def self.permitted_params
		base = [:id,{:package => [:report_name, {:report_ids => []}, :base_price, :discounted_price, :valid_till]}]
		if defined? @permitted_params
			
		else

		end
		base
	end	

end