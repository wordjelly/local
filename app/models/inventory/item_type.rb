require 'elasticsearch/persistence/model'
class Inventory::ItemType

	include Elasticsearch::Persistence::Model
	include Concerns::MissingMethodConcern
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::FormConcern
	include Concerns::VersionedConcern
	include Concerns::CallbacksConcern


	index_name "pathofast-inventory-item-types"
	document_type "inventory/item-type"

	## supplier is always you.
	## there is no other supplier.

	attribute :name, String
	validates_presence_of :name

	BARCODE_REQUIRED = "yes"
	BARCODE_NOT_REQUIRED = "no"
	BARCODE_OPTIONS = [BARCODE_REQUIRED,BARCODE_NOT_REQUIRED]
	DEFAULT_VIRTUAL_UNITS = 1

	attribute :barcode_required, String, :default => BARCODE_NOT_REQUIRED, mapping: {type: 'keyword'}

	attribute :virtual_units, Float, :default => DEFAULT_VIRTUAL_UNITS

	## the supplier id is only one and is the id of the organization to whom the user belongs.
	attribute :supplier_ids, Array, mapping: {type: 'keyword'}
	attr_accessor :supplier_name
	attr_accessor :suppliers

	attribute :manufacturer_name, String, mapping: {type: 'keyword'}

	## these are like 
	## serum tube(requirement)
	## and item type name is -> BD Gel seperator.
	## gel seperator tube -> can be from bd or anywhere
	## these are going to be used 
	## 
	attribute :categories, Array, mapping: {type: 'keyword'}

	mapping do 
		indexes :name,
			type: 'keyword',
		    fields: {
			      	:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
			      	}
		   	},
		   	copy_to: 'search_all'
		indexes :categories,
			type: 'keyword',
			copy_to: 'search_all'
	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["verified_by_user_ids","rejected_by_user_ids","active","versions"]
		}
	end


	## so how do we populate these?
	## for scalar fields form is pending.
	## all autocomplete on tags.
	## so we have included versioning into this also.
	## now we go forward and get it to create.
	## versioning UI also I want to complete today itself.
	def self.permitted_params
		base = [:id,{:item_type => [:name, :barcode_required, :virtual_units, :manufacturer_name, {:categories => []} ]}]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		base
	end

	before_save do |document|
		document.supplier_ids = [document.created_by_user.organization.id.to_s]
		if document.created_by_user.organization.is_a_supplier?
			document.public = Concerns::OwnersConcern::IS_PUBLIC
		end
		document.cascade_id_generation(nil)
	end
	

end