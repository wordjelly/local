require 'elasticsearch/persistence/model'
class Diagnostics::Report

	include Elasticsearch::Persistence::Model
	#include Concerns::StatusConcern
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
	attribute :tests, Array[Hash]
	attribute :requirements, Array[Hash]
	attribute :statuses, Array[Hash]
	attribute :rates, Array[Hash]
	attribute :payments, Array[Hash]
	attribute :price, Float
	validates :price, numericality: true
	attribute :outsource_to_organization_id, String, mapping: {type: 'keyword'}
	attribute :tag_ids, Array, mapping: {type: "keyword"}, default: []

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
		    indexes :statuses, type: 'nested', properties: {
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
		    		}
		    }
		    indexes :requirements, type: 'nested', properties: {
			    	quantity: {
			    		type: 'float'
			    	},
			    	categories: {
			    		type: 'nested',
			    		properties: {
			    			name: {
			    				type: 'keyword'
			    			},
			    			items: {
			    				type: 'nested',
			    				properties: {
			    					local_item_group_id: {
			    						type: 'keyword'
			    					},
			    					barcode: {
			    						type: 'keyword'
			    					}
			    				}
			    			}
			    		}
			    	}
		    	}
		    ## so tomorrow we go for collation.
		    ## then for fusion of statuses.
		    ## then for scheduling, and routines.
		    ## and last for order.
		    ## this will take about 
		    indexes :rates, type: 'nested', properties: {
		    	for_organization_id: {
		    		type: 'keyword'
		    	},
		    	rate: {
		    		type: 'float'
		    	}
		    }
		    indexes :tests, type: 'nested', properties: {
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
		    		type: "nested",
		    		properties: {
		    			min_age_years: {
		    				type: "integer"
		    			},
		    			min_age_months: {
		    				type: "integer"
		    			},
		    			min_age_days: {
		    				type: "integer"
		    			},
		    			min_age_hours: {
		    				type: "integer"
		    			},
		    			max_age_years: {
		    				type: "integer"
		    			},
		    			max_age_months: {
		    				type: "integer"
		    			},
		    			max_age_days: {
		    				type: "integer"
		    			},
		    			max_age_hours: {
		    				type: "integer"
		    			},
		    			sex: {
		    				type: "keyword"
		    			},
		    			grade: {
		    				type: "keyword"
		    			},
		    			count: {
		    				type: "float"
		    			},
		    			inference: {
		    				type: 'text'
		    			}
		    		}
		    	}
		    }	
		end
	end
	
	before_save do |document|

	end

	## collate n reports
	## add a report
	## remove a report
	## and update all the reports with the item requirements.
	## so there is a clone stage ?
	## yes
	## is there an assignment of an order
	## yes
	## lets start a basic order object.
	## and write the tests for that.
	
	def clone(patient_id,order_id)
		
		patient_report = Report.new(self.attributes.except(:id).merge({patient_id: patient_id, template_report_id: self.id.to_s}))
		
		patient_report.test_ids = []
		
		self.test_ids.each do |test_id|
			unless test_id.blank?
				t = Test.find(test_id)
				patient_test = t.clone(patient_id)
				patient_report.test_ids << patient_test.id.to_s
			end
		end

		patient_report.save
		## create a status, of the payment.

		Status.add_bill(patient_report,order_id)
		patient_report

	end

	## as long as there is no status that says collection completed
	## the 
	def can_be_cancelled?
		status_completed = self.statuses.select{|c|
			c.text_value == Status::COLLECTION_COMPLETED
		}
		status_completed.size == 0
	end

	def is_template_report?
		self.template_report_id.blank?
	end

	## so we add some status like this
	## for the test.

	def load_patient	
		unless self.patient_id.blank?
			begin
				self.patient = Patient.find(self.patient_id)
			rescue
				self.errors.add(:id,"patient #{self.patient_id} not found")
			end
		end
	end

	def load_tests
		puts " ------------------ loading tests -------------------- "
		self.tests ||= []
		self.test_ids.each do |tid|
			self.tests << Test.find(tid) unless tid.blank?
		end
		self.tests.map{|c| c.report_id = self.id.to_s}
		puts "self tests are:"
		puts self.tests.to_s
	end

	## we have to solve.
	## a bunch of issues
	## like rates
	## a certain organization may or may not use.
	## it needs to be copied from a template.
	## one action is customize.
	## another action is if i select a report ->
	## simplest thing is first copy it,
	## then use it.
	## first collate item requirements.
	## it will be create, from report.
	## and it will just pick up everything and save first.
	## 

	def load_item_requirements
		puts "--------------Came to load item requirements------------------"
		self.item_requirements_grouped_by_type = {}
		self.item_requirements ||= []
		self.item_requirement_ids.each do |iid|
			unless iid.blank? 
				ireq = ItemRequirement.find(iid)
				self.item_requirements << ireq
			end
		end
		self.item_requirements.map{|c| c.report_id = self.id.to_s }
		puts "the item requirements are:"
		puts self.item_requirements.to_s
	end

	def build_query
		queries = [{
			filter: {
				query: {
					match_all: {}
				}
			}
		}]

		self.attributes.each do |attr|
			if self.send(attr).class.to_s == "Array"
				unless self.send(attr).blank?
					if self.send(attr)[0] == "*"
						queries << {
							exists: {
								field: attr.to_sym.to_s
							}
						}
					else
						queries << {
							terms: {
								attr.to_s.to_sym => self.send(attr)
							}
						}
					end
				end
			elsif self.send(attr).class.to_s == "String"
				if self.send(attr) == "*"
					queries << {
						exists: {
							field: attr.to_sym.to_s
						}
					}
				else
					queries << {
						term: {
							attr.to_s.to_sym => self.send(attr)
						}
					}
				end
			elsif self.send(attr).class.to_s =~ /Float|Integer/
				queries << {
					range: {
						attr.to_s.to_sym => {
							gte: self.send(attr),
							lte: self.send(attr)
						}
					}
				}
			end
		end	
		queries
	end


	def self.permitted_params
		base = [
				:id,
				{:report => 
					[
						:patient_id,
						:price,
						:name, 
						:description,
						{:tag_ids => []},
						:outsource_to_organization_id,
						{
							:requirements => [
								:priority,
								{
									:categories => [
										:name,
										{
											:items => [
												:barcode,
												:local_item_group_id
											]
										}
									]
								}
							]
						},
				    	{
				    		:statuses => Diagnostics::Status.permitted_params
				    	},
				    	{
				    		:rates => [
				    			:for_organization_id,
				    			:rate
				    		]
				    	},
				    	{
				    		:payments => [
				    			:amount
				    		]
				    	},
				    	{
				    		:tests => [
				    			:name,
				    			:lis_code,
				    			:description,
				    			:price,
				    			:verified,
				    			{:references => []},
				    			:machine,
				    			:kit,
				    			{
				    				:ranges => [
				    					:min_age_years,
				    					:min_age_months,
				    					:min_age_days,
				    					:min_age_hours,
				    					:max_age_years,
				    					:max_age_months,
				    					:max_age_days,
				    					:max_age_hours,
				    					:sex,
				    					:grade,
				    					:count,
				    					:inference
				    				]
				    			}
				    		]
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



end