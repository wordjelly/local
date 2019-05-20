require 'elasticsearch/persistence/model'
class Inventory::ItemType

	include Elasticsearch::Persistence::Model
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern

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
	end
	## so we have included versioning into this also.
	## now we go forward and get it to create.
	## versioning UI also I want to complete today itself.
	def self.permitted_params
		base = [:id,{:item_type => [:name, :barcode_required, :virtual_units, :manufacturer_name]}]
		if defined? @permitted_params
			base[1][:item_type] << @permitted_params
			base[1][:item_type].flatten!
		end
		#puts "the base becomes:"
		#puts base.to_s
		base
	end

	before_save do |document|
		document.supplier_ids = [document.created_by_user.organization.id.to_s]
		if document.created_by_user.organization.is_a_supplier?
			document.public = Concerns::OwnersConcern::IS_PUBLIC
		end
	end
	
	## how to clone this shit.
	## if you are a supplier, make it public.	
	## next we have item_groups
	## give me the ui for that.
	## first make 3 item types
	## add them to the group
	## then 

end