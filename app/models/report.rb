require 'elasticsearch/persistence/model'
class Report

	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-reports"

	attribute :template_report_id, String, mapping: {type: "keyword"}

	attribute :test_ids, Array, mapping: {type: 'keyword'}, default: []

	attr_accessor :test_name
	attr_accessor :test_id_action
	attr_accessor :test_id
	attr_accessor :tests

	attribute :patient_id, String, mapping: {type: 'keyword'}
	## it can have an owner
	## it can also belong to an organization.
	## those come from the owner .
	## so we use owner concern.
	## we take them to the reports
	## we give them an option to choose the reports.
	## that they need, and do a bulk clone, with their organization id.
	## or on creating lab organization, clone all reports
	## as a bulk call.
	## both options are there.
	## call clone, and with the owner_ids.
	## provided that it doesn't exist for that organization.
	## suppose some new reports, are added, then we have to clone 
	## them for all the organizations ?
	## that will be a massive bulk call.
	## it just clones reports owned by pathofast.
	## that's it, just changes the organization id.
	## option b, if he changes something, then we have to be able to create a clone of that, and hook that into the clone call somehow.
	## i think that is a better bet.
	## reports index -> will go there.
	## it has a customize button everywhere.
	## we have to get into report creation.
	## report index.
	## report templates.
	## so we have to aggregate

	attribute :name, String

	attribute :price, Float
	validates :price, numericality: true

	attribute :item_requirement_ids, Array, mapping: {type: 'keyword'}, default: []

	attribute :statuses, Array[Hash]

	attribute :tag_ids, Array, mapping: {type: "keyword"}, default: []

	attr_accessor :item_requirement_name
	attr_accessor :item_requirement_id_action
	attr_accessor :item_requirement_id
	attr_accessor :item_requirements

	attr_accessor :item_requirements_grouped_by_type
	attr_accessor :patient

	attr_accessor :tag_name

	after_find do |document|
		document.load_patient
		document.load_tests
		document.load_item_requirements
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
		    indexes :statuses, type: 'nested', properties: {
		    	priority: {
		    		type: "integer"
		    	},
		    	name: {
		    		type: "keyword"
		    	},
		    	template_status_id: {
		    		type: "keyword"
		    	},
		    	expected_time: {
		    		type: "date"
		    	},
		    	assigned_to_employee_id: {
		    		type: "keyword"
		    	},
		    	requires_image: {
		    		type: "integer"
		    	},
		    	performed_at: {
		    		type: "date"
		    	},
		    	completed: {
		    		type: "integer"
		    	},
		    	comments: {
		    		type: "nested",
		    		properties: {
		    			comment: {
		    				type: "keyword",
		    				fields: {
		    					raw: {
		    						type: "text"
		    					}
		    				}
		    			},
		    			created_at: {
		    				type: "date"
		    			},
		    			created_by: {
		    				type: "keyword"
		    			}
		    		}
		    	}
		    }
		end
	end
	
	
	before_save do |document|
		if document.test_id_action
			unless document.test_id.blank?
				if document.test_id_action == "add"
					document.test_ids << document.test_id
				end
			end
		end
		
		if document.item_requirement_id_action
			unless document.item_requirement_id.blank?
				if document.item_requirement_id_action == "add"
					document.item_requirement_ids << document.item_requirement_id
				end
			end
		end
	end

	## so next step is simple.
	## we have to be able to show these statuses in different scenarios
	## first about the employees.
	## who is available to do what when.
	## and then aggregating that, together with a UI.
	## UI to update the status comments, and whatever else.
	## also UI to add employee schedules.
	## on the statuses.
	## normal ranges, alerts and formats of the reports, for pdf.
	## and sms.
	## interfacing with the app.
	## lets finish the interface for the status, in any and all situations.
	## tomorrow for UI of employees -> for jobs, as well as status allotment.
	## think how to put jobs into this.
	## maximum one week to finish all this.
	## one week more for control integration + LIS integration

	
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
		[:id , {:report => [:name,:test_id,:item_requirement_id, :test_id_action, :item_requirement_id_action, :price, {:status_ids => []}, {:tag_ids => []} ,{:test_ids => []}, {:item_requirement_ids => []}, :patient_id, :template_report_id ]}]
	end

end