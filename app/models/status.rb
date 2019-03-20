require 'elasticsearch/persistence/model'
class Status

	include Elasticsearch::Persistence::Model
	include Concerns::ImageLoadConcern

	index_name "pathofast-statuses"

	attribute :name, String, mapping: {type: 'keyword'}
	attribute :parent_ids, Array, mapping: {type: 'keyword'}
	attribute :report_id, String, mapping: {type: 'keyword'}
	attribute :numeric_value, Float
	attribute :text_value, String, mapping: {type: 'keyword'}
	attribute :item_id, String, mapping: {type: 'keyword'}
	attribute :item_group_id, String, mapping: {type: 'keyword'}
	attribute :order_id, String, mapping: {type: 'keyword'}
	attribute :response, Boolean
	attribute :patient_id, String, mapping: {type: 'keyword'}
	## so this priority has to be autoassigned.
	## for eg if you add a status, 
	## should it be grouped by the name or the priority ?
	## a particular status can have only one priority?
	## i mean where is the order of the statuses defined
	## to show the next step 
	## unless that status has multiple priorities.
	## for eg for hemogram
	## it is first-> add to roller -> add to belt
	## in serum tube -> directly -> add to belt.
	## suppose we give it a report index.
	## whenever we add it to a report.
	## and then we aggregate by that ?
	## like group by name ->
	## then each status has several indices
	## so we sort by what exactly?
	## we have to show a table
	## we want to apply current status
	## then we have to show 
	## on choosing a status -> we know which reports
	## it is applicable to .
	## whichever report the earlier status has been completed
	## only to that it can be applied.
	## okay so how do we sort it and show it
	## group by name.
	## sort by priority.
	## if two statuses have the same priority, show them together.
	## okay so how do i simulate this?
	## we need to create several statuses, and add them to a bunch of reports
	## but make priority compulsory for status.

	attribute :priority, Float
	validates_numericality_of :priority
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
		s.priority = 0
		puts "adding bill"
		response = s.save
		puts "add bill response: #{response}"
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
		unless self.report_id.blank?
			Report.find(self.report_id)
		end
	end

	def get_order
		unless self.order_id.blank?
			Order.find(self.order_id)
		end
	end

	def get_patient
		unless self.patient_id.blank?
			Patient.find(self.patient_id)
		end
	end

	def get_item
		unless self.item_id.blank?
			Item.find(self.item_id)
		end
	end

	def get_item_group
		unless self.item_group_id.blank?
			ItemGroup.find(self.item_group_id)
		end
	end

	## but then that aggregation will have to be done
	## everytime.

end