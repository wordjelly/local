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
	include Concerns::PdfConcern

	attribute :qualifications, Array, mapping: {type: 'keyword'}

	attribute :registration_number, Array, mapping: {type: 'keyword'}

	attribute :user_id, String, mapping: {type: 'keyword'}



end