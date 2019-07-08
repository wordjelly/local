require 'elasticsearch/persistence/model'
class Diagnostics::Status

	###########################################################
	##
	## STATUS CONSTANTS
	##
	###########################################################

	COLLECTION_COMPLETED = "collection completed"

	###########################################################
	##
	## 
	##
	###########################################################

	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern
	include Concerns::NameIdConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-statuses"
	LOT_SIZE = 1
	MAX_DELAY = 60
	DEFAULT_BUCKET_INTERVAL = 10
	##################################################
	##
	##
	## ATTRIBUTES IN USE
	##
	##
	#################################################
	attribute :name, String, mapping: {type: 'keyword'}
	attribute :description, String, mapping: {type: 'keyword'}
	attribute :duration, Integer, :default => 10
	## REQUIRED
	attribute :employee_block_duration, Integer, :default => 1
	## REQUIRED
	attribute :block_other_employees, Integer, :default => 1
	## the maximum number of these statuses that can be handled at any one time by any give employee.
	## REQUIRED
	attribute :reduce_prior_capacity_by, Integer, default: LOT_SIZE
	attribute :maximum_capacity, Integer, :default => 10
	## when this status is run, how much does the overall capacity reduce by, for the time duration.
	## i think this method should be placed on status itself.
	## so how to add this to block structure ?
	## okay so we have lot_size
	attribute :lot_size, Integer, default: LOT_SIZE
	attribute :requires_image, Integer, :default => 0
	attribute :result, String, mapping: {type: 'text'}
	attribute :from, Integer, mapping: {type: 'integer'}
	attribute :to, Integer, mapping: {type: 'integer'}
	attribute :bucket_interval, Integer, mapping: {type: 'integer'}, default: DEFAULT_BUCKET_INTERVAL

	## this is set if the status is copied from somewhere.
	## has to be a permitted parameter.

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

	    mappings dynamic: 'true' do
	      	indexes :information_keys, type: 'object'
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    }
		end

	end
	########################################################
	##
	##
	## CALLBACKS.
	##
	##
	########################################################
	before_save do |document|
		document.assign_id_from_name
	end
	
	########################################################
	##
	## UTILITY
	##
	########################################################
	def self.permitted_params
		[
			:name,
			:description,
			:duration,
			:employee_block_duration,
			:block_other_employees,
			:maximum_capacity,
			:lot_size,
			:requires_image,
			:result,
			:reduce_prior_capacity_by
		]
	end

	def self.index_properties
		{
			id: {
				type: 'keyword'
			},
    		name: {
    			type: 'keyword'
    		},
    		description: {
    			type: 'keyword'
    		},
    		duration: {
    			type: 'integer'
    		},
    		employee_block_duration: {
    			type: 'integer'
    		},
    		block_other_employees: {
    			type: 'keyword'
    		},
    		maximum_capacity: {
    			type: 'integer'
    		},
    		lot_size: {
    			type: 'integer'
    		},
    		requires_image: {
    			type: 'keyword'
    		},
    		result: {
    			type: 'text'
    		},
    		reduce_prior_capacity_by: {
    			type: 'integer'
    		}
	    }
	end


end