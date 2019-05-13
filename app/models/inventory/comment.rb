require 'elasticsearch/persistence/model'
class Inventory::Comment
	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	
	index_name "pathofast-inventory-comments"

	attribute :transaction_id, String, mapping: {type: 'keyword'}
	validate :transaction_id_exists

	attribute :comment_text, String, mapping: {type: 'text'}
	validates_presence_of :comment_text

	def transaction_id_exists
		self.errors.add(:transaction_id, "this transaction id does not exist") unless object_exists?("Inventory::Transaction",self.transaction_id)
	end

end