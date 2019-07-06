require 'elasticsearch/persistence/model'
class Diagnostics::Report

	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-diagnostics-reports"
	document_type "diagnostics/report"

	attribute :name, String, mapping: {type: 'keyword'}
	attribute :description, String, mapping: {type: 'keyword'}
	attribute :patient_id, String, mapping: {type: 'keyword'}
	attribute :tests, Array[Diagnostics::Test]
	attribute :requirements, Array[Inventory::Requirement]
	attribute :statuses, Array[Diagnostics::Status]
	attribute :rates, Array[Business::Rate]
	attribute :payments, Array[Business::Payment]
	attribute :price, Float
	validates :price, numericality: true
	attribute :outsource_to_organization_id, String, mapping: {type: 'keyword'}
	attribute :tag_ids, Array, mapping: {type: "keyword"}, default: []
	
	## calculated before_save in the set_procedure_version function
	attribute :procedure_version, String, mapping: {type: "keyword"}
	attribute :start_epoch, Integer, mapping: {type: 'integer'}
	## WE SET PERMITTED
	## AND THEN THE FIRST ACTION TO CHECK IS 

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
		    indexes :patient_id, type: 'keyword'
		    indexes :price, type: 'float'
		    indexes :outsource_to_organization_id, type: 'keyword'
		    indexes :tag_ids, type: 'keyword'
		    indexes :statuses, type: 'nested', properties: Diagnostics::Status.index_properties
		    indexes :requirements, type: 'nested', properties: Inventory::Requirement.index_properties
		    indexes :rates, type: 'nested', properties: Business::Rate.index_properties
		    indexes :tests, type: 'nested', properties: Diagnostics::Test.index_properties
			indexes :start_epoch, type: 'integer'
		end
	end
	
	before_save do |document|
		document.set_procedure_version
	end

	## generates a huge concated string using the reference status version 
	## of each status in the report.
	## then converts that into a base64 string.
	def set_procedure_version
		procedure_version = ''
		self.statuses.map{|c|
			procedure_version+= c.updated_at.to_s
		}
		self.procedure_version = Base64.encode64(procedure_version)
	end

	def self.permitted_params
		base = [
				:id,
				{:report => 
					[
						:id,
						:patient_id,
						:price,
						:name, 
						:description,
						:start_epoch,
						:procedure_version,
						{:tag_ids => []},
						:outsource_to_organization_id,
						{
							:requirements => Inventory::Requirement.permitted_params
						},
				    	{
				    		:statuses => Diagnostics::Status.permitted_params
				    	},
				    	{
				    		:rates => Business::Rate.permitted_params
				    	},
				    	{
				    		:tests => Diagnostics::Test.permitted_params
				    	}
					]
				}
			]
		if defined? @permitted_params
			base[1][:report] << @permitted_params
			base[1][:report].flatten!
		end
		base
	end

	def self.index_properties
		{
			:name => {
				:type => 'keyword',
				:fields => {
						:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
		      		}
				}
			},
			:patient_id => {
				:type => 'keyword'
			},
			:price => {
				:type => 'float'
			},
			:outsource_to_organization_id => {
				:type => 'keyword'
			},
			:tag_ids => {
				:type => 'keyword'
			},
			:requirements => {
				:type => 'nested',
				:properties => Inventory::Requirement.index_properties
			},
			:statuses => {
				:type => 'nested',
				:properties => Diagnostics::Status.index_properties
			},
			:rates => {
				:type => "nested",
				:properties => Business::Rate.index_properties
			},
			:tests => {
				:type => "nested",
				:properties => Diagnostics::Test.index_properties
			},
			:start_epoch => {
				:type => 'integer'
			}
		}
	end

	#############################################################
	##
	##
	## STATUS GROUPING
	##
	##
	#############################################################
	## @used_in: Concerns::Schedule::OrderConcern, to make the blocks.
	## @param[statuses] Array : Diagnostics::Status Objects.
	## @return[Hash]
	## key => duration
	## value => [status_id_one, status_id_two, status_id_three]s
	def self.group_statuses_by_duration(statuses)
		search_request = search({
			query: {
				nested: {
					path: "statuses",
					query: {
						bool: {
							should: statuses.map{|c|
								{
									term: {
										"statuses.id".to_sym => c.id.to_s
									}
								}
							}
						}
					}
				}
			},
			aggs: {
				duration_agg: {
					nested: {
						path: "statuses"
					},
					aggs: {
						status_duration: {
							terms: {
								field: "statuses.duration"
							},
							aggs: {
								status_ids: {
									terms: {
										field: "statuses.id"
									}
								}
							}
						}
					}
				}
			}
		})

		duration_to_statuses = {}
		search_request.response.aggregations.duration_agg.status_duration.buckets.each do |duration_bucket|
			duration = duration_bucket["key"]
			statuses = []
			duration_bucket.status_ids.buckets.each do |status_id_bucket|
				status_id = status_id_bucket["key"]
				statuses << status_id
			end
			duration_to_statuses[duration.to_s] = statuses
		end

		duration_to_statuses

	end	

	#############################################################
	##
	##
	## STATUS GROUPING ENDS.
	##
	##
	#############################################################

	## so it clears the items.
	def clear_all_items
		self.requirements.each do |req|
			req.categories.each do |cat|
				cat.items = []
			end
		end
	end

	## item has a remaining quantity.
	def add_item(category,item)
		self.requirements.each do |req|
			req.categories.each do |cat|
				if cat.name == category.name
					if item.has_space?(cat.quantity)
						item.deduct_space(cat.quantity)
						cat.items << item
					end
				end
			end
		end
	end



end	