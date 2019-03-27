require 'elasticsearch/persistence/model'

class ItemGroup

	include Elasticsearch::Persistence::Model

	index_name "pathofast-item-groups"

	attr_accessor :items

	attribute :item_ids, Array

	attribute :name, String

	attribute :barcode, String
	## group type needs autocomplete
	## barcode also needs autocomplete.
	attribute :group_type, String
	validates_presence_of :group_type
	validate :items_not_assigned_to_another_similar_type_group
	validate :all_items_exist

	def set_id_from_barcode
		self.id = self.barcode unless self.barcode.blank?
	end

	def all_items_exist
		self.item_ids.each do |iid|
			begin
				Item.find(iid)
			rescue
				puts "the item id not found is:"
				puts iid
				self.errors.add(:item_ids,"this item #{iid} does not exist")
			end
		end	
	end	

	def items_not_assigned_to_another_similar_type_group
		item_id_queries = self.item_ids.map{|c|
			c = {
					term: {
						item_ids: c
					}
				}
		}

		puts "item id queries are:"
		puts JSON.pretty_generate(item_id_queries)
		puts "------------------------------------------------"

		response = ItemGroup.search({
			query: {
				bool: {
					must: [
						{
							bool: {
								should: item_id_queries
							}
						},
						{
							term: {
								group_type: self.group_type
							}
						}
					]
				}
			}
		})
		if response.results.size > 0
			self.errors.add(:item_ids, "some of these items have already been assigned to other item groups")
		end
	end

	before_save do |document|
		document.set_id_from_barcode
		document.name = document.barcode
	end


	settings index: { 
	    number_of_shards: 1, 
	    number_of_replicas: 0,
	    analysis: {
		      	filter: {
			      	nGram_filter:  {
		                type: "nGram",
		                min_gram: 2,
		                max_gram: 20,
		               	token_chars: [
		                   "letter",
		                   "digit",
		                   "punctuation",
		                   "symbol"
		                ]
			        }
		      	},
	            analyzer:  {
	                nGram_analyzer:  {
	                    type: "custom",
	                    tokenizer:  "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding",
	                        "nGram_filter"
	                    ]
	                },
	                whitespace_analyzer: {
	                    type: "custom",
	                    tokenizer: "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding"
	                    ]
	                }
	            }
	    	}
	  	} do


	    mapping do
	      
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }

		end

	end	

	def load_associated_items
		self.items ||= []
		self.item_ids.each do |iid|
			begin
				self.items << Item.find(iid)
			rescue
			end
		end
		puts "the items are:"
		puts self.items.to_s
	end

	def prepare_items_to_add_to_order
		load_associated_items 
		response = {
			"item_requirements" => {}
		}
		self.items.each do |item|
			response["item_requirements"][item.item_type] ||= []
			## what is the item index for this type.

			response["item_requirements"][item.item_type] << 
			{"barcode" => item.id.to_s, "index" => response["item_requirements"][item.item_type].size, "type" => item.item_type}
		end

		response["item_requirements"]
	end

end