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
	## this is set if the status is copied from somewhere.
	## has to be a permitted parameter.
	
=begin
	## MAKING the report pdf -> collation and emailing.
	## all this is not too hard.
	## whether it should be outsourced or not.
	## FROM HERE ONWARDS IT IS NO LONGER REQUIRED.
	## SO STUFF LIKE CHECK FOR HEMOLYSIS.
	attribute :parent_ids, Array, mapping: {type: 'keyword'}
	attribute :report_id, String, mapping: {type: 'keyword'}
	attribute :numeric_value, Float
	attribute :text_value, String, mapping: {type: 'keyword'}
	attribute :item_id, String, mapping: {type: 'keyword'}
	attribute :item_group_id, String, mapping: {type: 'keyword'}
	attribute :order_id, String, mapping: {type: 'keyword'}
	attribute :response, Boolean
	attribute :patient_id, String, mapping: {type: 'keyword'}
	attribute :priority, Float
	attribute :tag_ids, String, mapping: {type: 'keyword'}
	
	## REQUIRED
	#attribute :duration, Integer, :default => 10
	## REQUIRED
	#attribute :employee_block_duration, Integer, :default => 1
	## REQUIRED
	#attribute :block_other_employees, Integer, :default => 1
	## the maximum number of these statuses that can be handled at any one time by any give employee.
	## REQUIRED
	#attribute :maximum_capacity, Integer, :default => 10

	## when this status is run, how much does the overall capacity reduce by, for the time duration.
	## i think this method should be placed on status itself.
	## so how to add this to block structure ?
	## okay so we have lot_size
	#attribute :lot_size, Integer, default: 1

	attr_accessor :tag_name

	## the total number of these statuses that have to be done, 
	## used onlyh in minute#build_minute_update_request_for_order
	attr_accessor :count
	## the tag id is the name.
	## so we can search directly.

	validates_numericality_of :priority
	## whether an image is compulsory for this status.
	

	attribute :information_keys, Hash

	attr_accessor :parents
	## whether the reports modal is to be shown.
	## used in status#index view, in each status, on clicking edit reports, in the options, it makes a called to statuses_controller#show, and there it 
	attr_accessor :show_reports_modal
	## the template reports that are not present in the parent_ids of the report.
	attr_accessor :template_reports_not_added_to_status
	
	## this is assigned to enable the UI to 
	## move the status up or down.
	attr_accessor :higher_priority
	attr_accessor :lower_priority

	#########################################################
	## FOR SCHEDULE.
	attr_accessor :add_status_schedule
	attr_accessor :from
	attr_accessor :to
	attr_accessor :employee_ids
	attr_accessor :divide_into
	#########################################################
=end
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


	# main thing after this is 
	# routines, and an api for that.
	# and patient portability with deep linking.
	# and then the report generation, and payments.
	# that will give us a working base.


end