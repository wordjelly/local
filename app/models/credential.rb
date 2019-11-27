require 'elasticsearch/persistence/model'
class Credential
	
	include Elasticsearch::Persistence::Model
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::SearchOptionsConcern
	include Concerns::CallbacksConcern


	attribute :qualifications, Array, mapping: {type: 'keyword'}

	attribute :registration_number, String, mapping: {type: 'keyword'}

	attribute :user_id, String, mapping: {type: 'keyword'}

	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s

	index_name "pathofast-credentials"
	document_type "credential"

	def self.permitted_params
		base = 
		[
			:id,
				{:credential => 
					[
						:id,
						:user_id,
						{:qualifications => []},
						:registration_number
					]
				}
		]
		base
	end

	def show_image_upload
		true
	end

end