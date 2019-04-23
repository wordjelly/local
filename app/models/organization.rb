require 'elasticsearch/persistence/model'

class Organization
	
	include Elasticsearch::Persistence::Model
	
	attribute :address, String, mapping: {type: 'keyword'}
	
	attribute :phone_number, String, mapping: {type: 'keyword'}

	attribute :logo_url, String, mapping: {type: 'keyword'}, :default => "/assets/default_logo.svg"

	attribute :user_ids, Array, mapping: {type: 'keyword'}

	validates_presence_of :address

	validates_presence_of :phone_number

end