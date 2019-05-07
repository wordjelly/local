require 'elasticsearch/persistence/model'
class Test	
	
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
		
	index_name "pathofast-tests"

	attr_accessor :normal_ranges
	## this is set when the tests are loaded, while viewing the report.
	## if the report id is set on the test, then in its options, we give a link to remove the test from that report, as an update.
	## the same is done for item requirements.
	## in order to add the report.
	## we give the test name.
	## and add the data attribute by default on that input element.
	attr_accessor :report_id

	## so this is an array and will need to be added using 
	## search like an array.
	## since the names are the ids, 
	## we can work with this.
	## we can have autocomplete.
	attribute :normal_range_ids, Array, default: []

	attribute :template_test_id, String

	attribute :search_options, Array

	## mapped in block
	attribute :name, String

	## mapped in block
	attribute :lis_code, String
	
	attribute :price, Float

	## mapped in block
	attribute :description, String

	## mapped in block
	attribute :patient_id, String
		
	attribute :email_status, String
	
	attribute :sms_status, String
	
	attribute :status, String

	attribute :tube_ids, Array

	## who all to notify at every status change.
	attribute :emails, Array

	## which mobile numbers to notify at every status change.
	attribute :mobile_numbers, Array

	## a list of factors causing elevated values
	attribute :factors_causing_elevated_values, Array, mapping: {type: 'keyword'}, default: []

	## a list of factors causing lower values.
	attribute :factors_causing_low_values, Array, mapping: {type: 'keyword'}, :default => []
	
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
	attribute :test_duration, Integer

	## when is this report expected
	attribute :report_expected_at, Integer

	## when was the report actually dispatched
	attribute :report_dispatched_at, Integer

	## what was the turn around time of the report.
	attribute :turn_around_time, Integer

	##############################################################
	##
	##
	## ALLOTMENT.
	## the technician to who the job has been alloted. 
	##
	##############################################################
	attribute :alloted_to_technician, String

	## item types have to be hard-coded.
	##############################################################
	##
	##
	## CHECKLISTS
	##
	##
	##############################################################
	attr_accessor :checklists_to_be_approved
	attr_accessor :normal_range_name

	##############################################################
	##
	##
	## CALLBACKS
	##
	##
	##############################################################
	after_find do |document|

		document.load_normal_ranges

	end

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

	       	indexes :status, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :report_name, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :patient_id, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :tube_ids, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :emails, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	      	indexes :mobile_numbers, type: 'keyword', fields: {
	      		:raw => {
	      			:type => "text",
	      			:analyzer => "nGram_analyzer",
	      			:search_analyzer => "whitespace_analyzer"
	      		}
	      	}

	    end
	end

	## now in order to remove the normal range, we just have to update it like that.
	## array update.
	## so i need to move to typeselector.
	## searching on name.
	## just like we are doing in report for some stuff.
	## same way in test for normal_ranges.
	
	def load_normal_ranges
		results = NormalRange.search({
			query: {
				ids: {
					values: self.normal_range_ids
				}
			}
		})
		self.normal_ranges = results.response.hits.hits.map{|c| NormalRange.find(c["_id"])}
	end

	def clone(patient_id)
		
		patient_test = Test.new(self.attributes.except(:id).merge({:patient_id => patient_id, :template_test_id => self.id.to_s}))


		patient_test.save

		patient_test

	end

	def self.permitted_params
		[:id , {:test => [:name,:lis_code,:description,:price]}]
	end

end