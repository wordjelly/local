require 'elasticsearch/persistence/model'
class Status

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
	attribute :priority, Float
	attribute :tag_ids, String, mapping: {type: 'keyword'}
	
	## REQUIRED
	attribute :duration, Integer, :default => 10
	## REQUIRED
	attribute :employee_block_duration, Integer, :default => 1
	## REQUIRED
	attribute :block_other_employees, Integer, :default => 1
	## the maximum number of these statuses that can be handled at any one time by any give employee.
	## REQUIRED
	attribute :maximum_capacity, Integer, :default => 10


	attr_accessor :tag_name

	## the total number of these statuses that have to be done, 
	## used onlyh in minute#build_minute_update_request_for_order
	attr_accessor :count
	## the tag id is the name.
	## so we can search directly.

	validates_numericality_of :priority
	## whether an image is compulsory for this status.
	attribute :requires_image, Integer, :default => 0

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
	after_find do |document|
		document.load_parents
		document.load_template_reports_not_added_to_status
	end

	before_save do |document|

		unless document.add_status_schedule.blank?
			document.add_schedule(document.from,document.to,document.employee_ids,self.id.to_s)
		end
	end

	## suppose i give for em200
	## can another person operate it again?
	## no so the status is to be removed for other people
	## for the booked duration, remove it for everyone else, and that employee also.
	## that's what has to be done.
	## and all this in one bulk call.
	## so where will we add this bulk item?
	## on minute.

	def add_schedule(from,to,employee_ids,status_id,divide_equally)
		Minute.get_minute_ids(document.from,document.to).each do |min_id|
			update_request = Minute.update_minute(min_id,{status_id: status_id, employee_ids: employee_ids})
			Minute.add_bulk_item(update_request)
		end
		Minute.flush_bulk
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
		s.parent_ids = [order_id.to_s,patient_report.id.to_s]
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
			begin
				Order.find(self.order_id)
			rescue

			end
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

	## @used_in : order, #update_tubes.
	## takes all the template report ids, and builds this hash.
	## then passes that into clone report, so that these statuses can be pushed into each report's statuses.
	## @return[Hash] : with the following structure:
	## {
	##   reports_to_statuses_hash : {
	##	 	"report_id" : 
	##			{
	##          	priority: ,
	## 				name: ,
	##          	template_status_id: ,
	##          	requires_image: ,
	## 				duration: 
	##			}
	##   	}
	##   },
	##   statuses_to_reports_hash: {
	##      "status_id" : {
	##              reports: [r1,r2,r3],
	##              duration: 1003 
	##       }
	##	 }
	## }
	## first lets test this returned hash.
	## then we go for the cloning, and attribution.
	def self.get_statuses_for_report_ids(template_report_ids)
		puts "Searching for template report ids"
		puts template_report_ids.to_s 
		puts "-------------------------------------------------"
		results = Status.search({
			query: {
				bool: {
					must_not: [
						{
							exists: {
								field: "patient_id"
							}
 						},
 						{
 							exists: {
 								field: "order_id"
 							}
 						},
 						{
 							exists: {
 								field: "report_id"
 							}
 						}
					],
					must: [
						{
							terms: {
								parent_ids: template_report_ids
							}
						}
					]
				}
			},
			aggs: {
				template_report_ids: {
					terms: {
						field: "parent_ids",
						include: template_report_ids
					},
					aggs: {
						status_ids: {
							terms: {
								field: "_id",
								size: 100,
								order: { 
									priority: "asc" 
								}
							},
							aggs: {
								priority: {
									max: {
										field: "priority"
									}
								},
								name: {
									terms: {
										field: "name"
									}
								},
								template_status_id: {
									terms: {
										field: "_id"
									}
								},
								requires_image: {
									terms: {
										field: "requires_image"
									}
								},
								duration: {
									terms: {
										field: "duration"
									}
								}
							}
						}
					}
				},
				status_ids: {
					terms: {
						field: "_id",
						order: {
							priority: "asc"
						}
					},
					aggs: {
						reports: {
							terms: {
								field: "report_id"
							}
						},
						duration: {
							min: {
								field: "duration"
							}
						},
						priority: {
							min: {
								field: "priority"
							}
						},
						maximum_capacity:{
							min:{
								field: "maximum_capacity"
							}
						}
					}
				}
			}
		})

		statuses_to_reports_hash = {}

		results.response.aggregations.status_ids.buckets.each do |status_id_bucket|

			status_id = status_id_bucket["key"]
			reports = []
			duration = nil
			priority = nil

			reports = status_id_bucket.reports.buckets.map{|c| c["key"]}
			duration = status_id_bucket.duration.min[1]
			priority = status_id_bucket.priority.min[1]
			#puts status_id_bucket.to_s
			#exit(1)
			maximum_capacity = status_id_bucket.maximum_capacity.min[1]

			statuses_to_reports_hash[status_id] = 
			{
				reports: reports,
				duration: duration,
				maximum_capacity: maximum_capacity
			}

		end

		reports_to_statuses_hash = {}
		results.response.aggregations.template_report_ids.buckets.each do |bucket|
			template_report_id = bucket["key"]
			reports_to_statuses_hash[template_report_id] = []
			unless bucket.status_ids.buckets.blank?
				bucket.status_ids.buckets.each do |status_id|
					
					reports_to_statuses_hash[template_report_id] << 
					{
						priority:  status_id.priority.value,
						name: status_id["name"].buckets[0]["key"],
						template_status_id: status_id["template_status_id"].buckets[0]["key"],
						requires_image: status_id["requires_image"].buckets[0]["key"],
						duration: status_id["duration"].buckets[0]["key"]
					}
				end
			end
		end



		{
			reports_to_statuses_hash:  reports_to_statuses_hash,
			statuses_to_reports_hash: statuses_to_reports_hash
		}
		


	end

	def load_parents
		self.parents = []
		results = Elasticsearch::Persistence.client.search index: "pathofast-*", body: {
			query: {
				ids: {
					values: self.parent_ids
				}
			}
		}

		results = Hashie::Mash.new results

		#puts results.hits.to_s

		search_results = []

		results.hits.hits.each do |hit|
			obj = hit._type.capitalize.constantize.new(hit._source)
			obj.id = hit._id
			search_results << obj
			obj.run_callbacks(:find)
		end	

		self.parents = search_results

	end
		

	def load_template_reports_not_added_to_status

		self.template_reports_not_added_to_status = Report.search({
			query: {
				bool: {
					must_not: [
						{
							exists: {
								field: "template_report_id"
							}
						},
						{
							exists: {
								field: "patient_id"
							}
						},
						{
							ids: {
								values: self.parent_ids 
							}
						}
					]
				}
			}
		})

		self.template_reports_not_added_to_status.map!{|c|
			r = Report.new(c["_source"])
			r.id = c["_id"]
			c = r
			r.run_callbacks(:find)
			r
		}

	end

	def self.decr(priority)
		priority - 0.1
	end

	def self.incr(priority)
		priority + 0.1
	end

	def self.higher_priority(statuses,self_key)
		if self_key == 0
			statuses[0].priority
		elsif self_key == 1
			decr(statuses[0].priority)
		else
			(statuses[self_key - 2].priority + statuses[self_key - 1].priority)/2
		end
	end


	def self.lower_priority(statuses,self_key)
		statuses_size = statuses.size
		if self_key == (statuses_size - 1)
			## it is the last element.
			statuses[self_key].priority
		elsif self_key == (statuses_size - 2)
			## it is the second last element.
			incr(statuses[self_key + 1].priority)
		else
			## we take the next two elements , and average them.
			(statuses[self_key + 2].priority + statuses[self_key + 1].priority)/2
		end
	end

	## imagine we are only interested in pending reports.
	## so what is a pending report ?
	## a report where a particular status has not yet been performed.
	## for eg: verified.
	## we also want to see only the last performed status, not all from the beginning.
	## so we include, where performed_at exists is false.
	## and performed_at, for status name "verified" is also false.
	## how do you sort the reports ?
	## it would be better to have the outer by report_id.
	## so that we can proceed those as rows, and sort also .
	## then we want to sort the reports that are being shown, inside each status.
	## we will first gather by the 
	## by default sorts by the most delayed status.
	## we want all reports with patient_id.
	## so lets call gather_Statuses and see what happens.
	## so tomorrow the status display, and then equipment applicability for the tube for the reports, and employee 
	def self.gather_statuses(query_clauses=nil)
		query_clauses ||= {
			bool: {
				must: [
					{
						exists: {
							field: "patient_id"
						}
					}
				]
			}
		}
		search_results = Report.search({
			query: query_clauses,
			aggs: {
				statuses: {
					nested: {
						path: "statuses"
					},
					aggs: {
						status_ids: {
							terms: {
								field: "statuses.template_status_id",
								order: {
									priority: "asc"
								}
							},
							aggs: {
								priority: {
									min: {
										field: "statuses.priority"
									}
								},
								name: {
									terms: {
										field: "statuses.name"
									}
								}
							}
						}
					}
				},
				reports: {
					terms: {
						field: "_id",
				        size: 10,
				        order: {
				          "delay>expected_time".to_sym => "desc"
				        }
					},
					aggs: {
						name: {
							terms: {
								field: "name"
							}
						},
						patient_id: {
							terms: {
								field: "patient_id"
							}
						},
						order_id: {
							terms: {
								field: "order_id"
							}
						},
						delay: {
							nested: {
								path: "statuses"
							},
							aggs: {
								expected_time: {
									filter: {
										term: {
											"statuses.completed".to_sym => 0
										}
									},
									aggs: {
										eta: {
											min: {
												field: "statuses.expected_time"
											}
										}
									}
								},
								template_status_id: {
									terms: {
										field: "statuses.template_status_id",
										order: {
											priority: "asc"
										}
									},
									aggs: {
										priority: {
											min: {
												field: "statuses.priority"
											}
										},
										expected_time: {
											min: {
												field: "statuses.expected_time"
											}
										},
										name: {
											terms: {
												field: "statuses.name"
											}
										},
										assigned_to_employee_id: {
											terms: {
												field: "statuses.assigned_to_employee_id"
											}
										},
										performed_at: {
											min: {
												field: "statuses.performed_at"
											}
										},
										comments: {
											nested: {
												path: "statuses.comments"
											},
											aggs: {
												individual_comment: {
													terms: {
														field: "statuses.comments.comment"
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}	
		})

		reports = []
		statuses = []
		## we aslo need the statuses in a seperate array to make it possible to display them.
		## then we give the UI to update it.
		#puts "these are the aggs------------->"
		#puts search_results.response.hits
		#puts search_results.response.aggregations.to_s
		search_results.response.aggregations.statuses.status_ids.buckets.each do |status_bucket|
			status = {}
			status[:id] = status_bucket["key"]
			status_bucket.name.buckets.each do |name_bucket|
				status[:name] = name_bucket["key"]
			end
			statuses << status
		end

		search_results.response.aggregations.reports.buckets.each do |report_bucket|

			report_id = report_bucket["key"]
			order_id = nil
			order_id = report_bucket.order_id.buckets[0]["key"] unless report_bucket.order_id.buckets.blank?
			report = {id: report_id, statuses: [],
				 name: report_bucket.name.buckets[0]["key"],
				patient_id: report_bucket.patient_id.buckets[0]["key"], 
				order_id: order_id 
			}			

			report_bucket.delay.template_status_id.buckets.each do |template_status_id_bucket|

				status = {}

				status[:template_status_id] = template_status_id_bucket["key"]

				status[:priority] = template_status_id_bucket.priority.value

				status[:expected_time] = template_status_id_bucket.expected_time.value

				status[:name] = template_status_id_bucket.name.buckets[0]["key"]

				status[:assigned_to_employee_id] = template_status_id_bucket.assigned_to_employee_id.buckets[0]["key"] unless template_status_id_bucket.assigned_to_employee_id.buckets[0].blank?

				status[:performed_at] = template_status_id_bucket.performed_at.value

				puts "this is the template status id bucket------------------------------------"
				puts template_status_id_bucket.to_s
				puts "these are the comments"
				puts template_status_id_bucket.comments.to_s

				puts template_status_id_bucket.comments.individual_comment.to_s

				status[:comments] = template_status_id_bucket.comments.individual_comment.buckets.map{|c| c["key"]} unless (template_status_id_bucket.comments.individual_comment.blank? && template_status_id_bucket.comments.individual_comment.buckets.blank?)

				report[:statuses] << status

			end

			reports << report

		end	

		puts " -------- these are the aggregated reports ------ "
		puts JSON.pretty_generate(reports)
		puts " -------- these are the aggregated status ids ---"
		puts JSON.pretty_generate(statuses)

		## returns a hash with reports and statuses.
		## this will have to be changed, because now the cancellation and reallotment happens at the minute level.
		## 

		{reports: reports, statuses: statuses}

	end	


end