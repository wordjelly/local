require 'elasticsearch/persistence/model'
class Inventory::Comment
	include Elasticsearch::Persistence::Model
	include Concerns::MissingMethodConcern
	include Concerns::AllFieldsConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::FormConcern
		include Concerns::CallbacksConcern

	
	index_name "pathofast-inventory-comments"
	document_type "inventory/comment"


	attribute :transaction_id, String, mapping: {type: 'keyword', copy_to: "search_all"}
	validate :transaction_id_exists

	attribute :comment_text, String, mapping: {type: 'text', copy_to: "search_all"}
	validates_presence_of :comment_text

	def transaction_id_exists
		self.errors.add(:transaction_id, "this transaction id does not exist") unless object_exists?("Inventory::Transaction",self.transaction_id)
	end

	def self.permitted_params
		base = [:id,{:comment => [:transaction_id, :comment_text]}]
		if defined? @permitted_params
			base[1][:comment] << @permitted_params
			base[1][:comment].flatten!
		end
		base
	end

end