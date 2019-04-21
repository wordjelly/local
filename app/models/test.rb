require 'elasticsearch/persistence/model'
class Test	
	
	include Elasticsearch::Persistence::Model
		
	index_name "pathofast-tests"

	attr_accessor :normal_ranges

	## this is set when the tests are loaded, while viewing the report.
	## if the report id is set on the test, then in its options, we give a link to remove the test from that report, as an update.
	## the same is done for item requirements.
	## in order to add the report.
	## we give the test name.
	## and add the data attribute by default on that input element.
	attr_accessor :report_id

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
	
	def load_normal_ranges
		results = NormalRange.search({
			query: {
				term: {
					test_id: self.id.to_s
				}
			}
		})
		self.normal_ranges = results.response.hits.hits
	end

	def clone(patient_id)
		
		patient_test = Test.new(self.attributes.except(:id).merge({:patient_id => patient_id, :template_test_id => self.id.to_s}))


		patient_test.save

		patient_test

	end

end