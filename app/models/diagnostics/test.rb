require 'elasticsearch/persistence/model'
class Diagnostics::Test	
	
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
		
	index_name "pathofast-tests"



	#attr_accessor :normal_ranges
	
	#attr_accessor :report_id

	#attribute :normal_range_ids, Array, default: []

	#attribute :template_test_id, String

	#attribute :search_options, Array

	## mapped in block
	attribute :name, String

	## mapped in block
	attribute :lis_code, String
	
	attribute :price, Float

	## mapped in block
	attribute :description, String

	## mapped in block
	#attribute :patient_id, String
		
	#attribute :email_status, String
	
	#attribute :sms_status, String
	
	#attribute :status, String

	#attribute :tube_ids, Array

	## who all to notify at every status change.
	#attribute :emails, Array

	## which mobile numbers to notify at every status change.
	#attribute :mobile_numbers, Array

	## a list of factors causing elevated values
	#attribute :factors_causing_elevated_values, Array, mapping: {type: 'keyword'}, default: []

	## a list of factors causing lower values.
	#attribute :factors_causing_low_values, Array, mapping: {type: 'keyword'}, :default => []
	
	## references
	attribute :references, Array, mapping: {type: 'keyword'}, default: []
	##############################################################
	##
	##
	## TIMING.
	##
	##
	##############################################################

	## how long does this test usually take.
	#attribute :test_duration, Integer

	## when is this report expected
	#attribute :report_expected_at, Integer

	## when was the report actually dispatched
	#attribute :report_dispatched_at, Integer

	## what was the turn around time of the report.
	#attribute :turn_around_time, Integer

	##############################################################
	##
	##
	## ALLOTMENT.
	## the technician to who the job has been alloted. 
	##
	##############################################################
	#attribute :alloted_to_technician, String

	## item types have to be hard-coded.
	##############################################################
	##
	##
	## CHECKLISTS
	##
	##
	##############################################################
	#attr_accessor :checklists_to_be_approved
	#attr_accessor :normal_range_name

	
	##############################################################
	##
	##
	## 
	##
	##############################################################

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

	      	indexes :lis_code, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :description, type: 'text'

	    end

	end

=begin
	def self.permitted_params
		[:id , {:test => [:name,:lis_code,:description,:price]}]
	end
=end
	
	def self.permitted_params

		[
			:name,
			:lis_code,
			:description,
			:price,
			:verified,
			{:references => []},
			:machine,
			:kit,
			{
				:ranges => Diagnostics::Range.permitted_params
			}
		]

	end

	def self.index_properties
		{
	    	name: {
	    		type: 'keyword',
	    		fields: {
	    			:raw => {
	    				:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
	    			}
		    		}
	    	},
	    	lis_code: {
	    		type: 'keyword'
	    	},
	    	description: {
	    		type: 'keyword',
	    		fields: {
	    			:raw => {
	    				:type => "text"
	    			}
	    		}
	    	},
	    	price: {
	    		type: 'float'
	    	},
	    	verified: {
	    		type: 'boolean'
	    	},
	    	references: {
	    		type: 'keyword'
	    	},
	    	machine: {
	    		type: 'keyword'
	    	},
	    	kit: {
	    		type: 'keyword'
	    	},
	    	ranges: {
	    		type: 'nested',
	    		properties: Diagnostics::Range.index_properties
	    	}
	    }	
	end

end