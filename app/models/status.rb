require 'elasticsearch/persistence/model'
class Status

	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern

	index_name "pathofast-statuses"

	attribute :name, String
	attribute :parent_ids, Array
	attribute :report_id, String
	attribute :numeric_value, Float
	attribute :text_value, String
	attribute :item_id, String
	attribute :item_group_id, String
	attribute :order_id, String
	attribute :response, Boolean
	attribute :patient_id, String
	attribute :priority, Float
	## whether an image is compulsory for this status.
	attribute :requires_image, Boolean

	attribute :information_keys, Hash

	## status will be created with a name
	## like payment_made, so we may need some additional information
	## so this will be provided in a key -> value
	## format
	## like amount -> x.
	## so we can then perform operations on that.
	## about payments.
	## so we keep that dynamic mapping.

	## will call a method named "on_#{name}" after create on 
	## each object who can be resolved, in a background job.
	## so if status is verified
	## will call on_verified , on report, item, item_group, and order
	## if the method does not exist, won't do anything
	## will store the results of calling that method, on the object
	## if the object wants to call that method again, it has to set that status again.
	## if it has to be retried.
	## if the job fails, the status gets marked as failed.
	## and will give the reason for it.

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
	## UTILITY
	##
	########################################################
	## creates a bill for the report.
	def self.add_bill(patient_report,order_id)	
		s = Status.new
		s.report_id = patient_report.id.to_s
		s.order_id = order_id
		s.numeric_value = patient_report.price
		s.text_value = patient_report.name
		s.name = "bill"
		s.save
	end


	def belongs_to
		## here we want to search across all models.
		## that is going to be the biggest challenge hereforth.
		#gateway.client.search index: "correlations", body: body
		results = Elasticsearch::Persistence.client.search index: "pathofast-*", body: {
			query: {
				term: {
					status_ids: self.id.to_s
				}
			}
		}

		results = Hashie::Mash.new results

		puts results.hits.to_s

		search_results = []

		results.hits.hits.each do |hit|
			obj = hit._type.capitalize.constantize.new(hit._source)
			obj.id = hit._id
			search_results << obj
		end	

		search_results

	end

	def get_report
		if self.report_id
			Report.find(self.report_id)
		end
	end

	def get_order
		if self.order_id
			Order.find(self.order_id)
		end
	end

	def get_patient
		if self.patient_id
			Patient.find(self.patient_id)
		end
	end

	def get_item
		if self.item_id
			Item.find(self.item_id)
		end
	end

	def get_item_group
		if self.item_group_id
			ItemGroup.find(self.item_group_id)
		end
	end




end