require 'elasticsearch/persistence/model'

class Item

	include Elasticsearch::Persistence::Model

	include Concerns::ImageLoadConcern

	include Concerns::StatusConcern

	index_name "pathofast-items"

	attribute :item_type, String
	validates_presence_of :item_type

	attribute :name, String

	attribute :location, String

	attribute :filled_amount, Float

	attribute :expiry_date, DateTime
	validates_presence_of :expiry_date

	attribute :barcode, String
	validates_presence_of :barcode

	attribute :contents_expiry_date, DateTime	

	def set_id_from_barcode
		self.id = self.barcode unless self.barcode.blank?
	end

	before_save do |document|
		document.name = document.barcode
		document.set_id_from_barcode
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

	## for this tube what all statuses are there.
	## for this get all the report ids that are registered on it.
	## then aggregate their statuses.
	## so that is the issue
	## even the statuses will have to be created
	## with the reports.
	## and show those steps.
	## that's how it works.
	## when a report is 
	## so let me create an order and see how it looks.
	def get_applicable_statuses
		## ideally we can search for all of them together as well.
		## but for one item, it is better to gather individually.
		results = Order.search({
			size: 1,
			_source: ["item_requirements"],
			query: {
				match: {
					"item_requirements.#{self.item_type}.barcode".to_sym => self.id.to_s
				}
			}
		})

		applicable_report_ids = []
		results.response.each do |order|
			req = order.item_requirements[self.item_type].select{|c|
				c["barcode"] = self.id.to_s
			}
			applicable_report_ids = req["report_ids"]
			applicable_template_report_ids = req["template_report_ids"]
		end

		Status.search({
			query: {
				terms: {
					report_id: req["report_ids"] + req["template_report_ids"]
				}
			},
			aggs: {

			}
		})
		## get me all the statuses that belong to that template.
		## statuses which have
		## template_report_id
		## or base report id
		## then group by status name.
		## sort by priority.
		## wherever a report id is there, 
		## that has already been done.
		## wherever its not there, that has no yet been done.
		## and sort by priority order.
		## and aggregate. also.
		## now we take these applicable report ids.
		## we need to get their template report ids.
		## then we need to aggregate on the statuses?



	end


end