require 'elasticsearch/persistence/model'
class Order

	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern
	include Concerns::PdfConcern
	
	index_name "pathofast-orders"

	attr_accessor :patient_name

	attr_accessor :account_statement

	attribute :patient_id, String

	attribute :patient_test_ids, Array

	attribute :patient_report_ids, Array

	attribute :template_report_ids, Array

	attribute :tubes, Array[Hash]

	## this is for the external api.
	attribute :external_reference_number, String, mapping: {type: 'keyword'}

	attribute :start_time, Date
	validates_presence_of :start_time

	attribute :item_group_id
	attribute :item_group_action

	attr_accessor :patient
	attr_accessor :reports
	attr_accessor :cloned_reports
	attr_accessor :report_name
		
=begin

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
		    indexes :tubes, type: 'nested', properties: {
		    	item_requirement_name: {
		    		type: 'keyword'
		    	},
		    	patient_report_ids: {
		    		type: 'keyword'
		    	},
		    	occupied_space: {
		    		type: 'float'
		    	},
		    	template_report_ids: {
		    		type: 'keyword'
		    	},
		    	barcode: {
		    		type: 'keyword'
		    	},
		    	item_group_id: {
		    		type: 'keyword'
		    	}
		    }
		end

	end

	validates_presence_of :patient_id	


	
	before_save do |document|
		document.update_barcodes
		document.update_tubes
	end

	after_find do |document|
		document.load_patient
		document.load_patient_reports
		document.generate_account_statement
		document.generate_pdf
	end

	def load_patient_reports
		self.reports ||= []
		get_patient_report_ids.each do |pid|
			self.reports << Report.find(pid)
		end
	end

	def existing_template_report_ids
		self.tubes ||= []
		self.tubes.map{|c|
			c["template_report_ids"]
		}.flatten.uniq
	end
	
	## returns the id of the patient report.
	## won't reclone the report if its already cloned
	## only applicable intra sesssion.
	## so we clone some of the applicable reports.
	## and we added those tubes
	## but it doesn't become transactional.
	## so it may reclone, and screw up the bill.
	def clone_report(report_id,statuses)	
		self.cloned_reports ||= {}
		if self.cloned_reports[report_id].blank?
			self.cloned_reports[report_id] = Report.find(report_id).clone(self.patient_id,self.id.to_s,statuses,self.start_time).id.to_s
		end
		self.cloned_reports[report_id]
	end

	## @param[Hash] args: Hash of the tube definition.
	## It will include the following keys.
	## :item_requirement_name
	## :template_report_ids
	## :required_space
	## @return[Hash] 
	def add_tube_requirement(args)
		last_index = self.tubes.rindex{|x|
			x["item_requirement_name"] == args["item_requirement_name"]
		}
		if last_index.blank?
			self.tubes << args
		else
			if (100 - self.tubes[last_index]["occupied_space"]) >= args["occupied_space"]
				self.tubes[last_index]["template_report_ids"]+= args["template_report_ids"]
				self.tubes[last_index]["patient_report_ids"]+= args["patient_report_ids"]
				self.tubes[last_index]["occupied_space"]+= args["occupied_space"]
			else
				self.tubes << args
			end
		end
	end

	def update_barcodes
		if(Set.new(existing_template_report_ids) == Set.new(self.template_report_ids))
			if self.item_group_id.blank?
				self.tubes.map{|tube|
					unless tube["item_group_id"].blank?
						tube["barcode"] = nil 
						tube["item_group_id"] = nil
					end
				}
			else
				item_group = ItemGroup.find(item_group_id)
				tube_indices_assigned = []
				item_group.load_associated_items

				item_group_indices = {}

				#puts "-------------- these are the items -------------"
				#item_group.items.each do |item|
				#	puts JSON.pretty_generate(item.attributes)
				#end
				#puts "-------------- items end -----------------------"


				item_group.items.each_with_index{|item,ikey|
					#self.tubes.map.each_with_index

					item_group_indices[ikey.to_s] = nil
					self.tubes.map.each_with_index{|tube,key|
						unless tube_indices_assigned.include? key
							if tube["item_requirement_name"] == item.item_type
								#self.tubes[key]["barcode"] = item.barcode
								#self.tubes[key]["item_group_id"] = item_group.id.to_s
								item_group_indices[ikey.to_s] = key
								tube_indices_assigned << key 
							end
						end
					}
				}

				item_group_indices.keys.each do |ikey|
					unless item_group_indices[ikey].blank?
						#puts " -------- setting tube data ----------- "
						self.tubes[item_group_indices[ikey]]["barcode"] = item_group.items[ikey.to_i].barcode
						self.tubes[item_group_indices[ikey]]["item_group_id"] = item_group.id.to_s
					end
				end

			end
				
			#puts JSON.pretty_generate(self.tubes)

			self.tubes.each do |tube|
				unless tube["barcode"].blank?
					other_order_has_barcode?(tube["barcode"])
					item_type_is_equivalent?(tube["barcode"],tube["item_requirement_name"])
				end
			end	
		end
	end

	def update_tubes
		## first delete the reports that have been removed.
		## if there is no difference only then we check the barcodes.

		(existing_template_report_ids - self.template_report_ids).each do |template_report_id_to_remove|
			
			self.tubes.map{|c|
				if arrind = c["template_report_ids"].index(template_report_id_to_remove)
					patient_report = Report.find(c["patient_report_ids"][arrind])
					patient_report.load_statuses
					if patient_report.can_be_cancelled?
						c["template_report_ids"].delete_at(arrind)
						c["patient_report_ids"].delete_at(arrind)
						ireq = ItemRequirement.search({
							query: {
								term: {
									name: c["item_requirement_name"]
								}
							}
						}).response.hits.hits.first._source
						#puts ireq.to_s
						#puts ireq.class.name
						ireq = ItemRequirement.new(ireq)
						#puts ireq.to_s
						ireq.get_amount_for_report(template_report_id_to_remove)
						#puts "-------------------------------"
						c["occupied_space"]-= ireq.get_amount_for_report(template_report_id_to_remove)
					else
						## so we add it back to the current template report ids, because that patient report can no longer be cancelled.
						self.template_report_ids << template_report_id_to_remove
					end
				end
			}
		end

		report_ids_to_add = self.template_report_ids - existing_template_report_ids

		## so we want to cater only for these.
		## these have come with each report seperately
		## but we want it actually status wise
		## and the count of the reports.
		## that is something that we can directly check
		## for compatibility
		## we also need the timings of the statuses
		statuses_and_reports = Status.get_statuses_for_report_ids(report_ids_to_add)

		reports_to_statuses_hash = statuses_and_reports[:reports_to_statuses_hash]

		statuses_to_reports_hash = statuses_and_reports[:statuses_to_reports_hash]

		
		## so we clone them with the relevant statuses.

		required_item_amounts = ItemRequirement.search({
			query: {
				bool: {
					filter: {
						nested: {
							path: "definitions",
							query: {
								terms: {
									"definitions.report_id".to_sym => report_ids_to_add
								}
							}
						}
					}
				}
			},
			aggs: {
				item_types: {
					terms: {
						field: "item_type",
						size: 100
					},
					aggs: {
						item_requirements: {
							terms: {
								field: "name",
								size: 100,
								order: {"priorities>min_priority".to_sym => "asc"}
							},
							aggs: {
								priorities: {
									nested: {
										path: "definitions"
									},
									aggs: {
										min_priority: {
											min: {
												field: "definitions.priority"
											}
										}
									}
								},
								amounts: {
									nested: {
										path: "definitions"
									},
									aggs: {
										required_reports: {
											filter: {
												terms: {
													"definitions.report_id".to_sym => report_ids_to_add
												}
											},
											aggs: {
												sum_amount: {
													sum: {
														field: "definitions.amount"
													}
												},
												applicable_reports: {
													terms: {
														field: "definitions.report_id"
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

		required_item_amounts.response.aggregations.item_types.buckets.each do |item_type|
			item_type.item_requirements.buckets.each do |ir|
				tube_type = ir["key"]
				required_amount = ir.amounts.required_reports.sum_amount.value
				applicable_reports = ir.amounts.required_reports.applicable_reports.buckets.map{|c| c = c["key"]}
				## so what do we want to clone here exaclty ?
				## template_report ids.
				## we get the applicable statuses.
				## and clone them into the patient reports.
				## so given those template_report_ids
				## we want all the statuses
				## we send the statuses, while cloning the reports
				## that are applicable to the parent report
				## at the same time we also send in the tags.
				## that we want to use.
				## these can be chosen
				## so search for the statuses,
				## then group by template_report id.
				## and internally sort by the priority of the status.
				patient_report_ids = applicable_reports.map{|c|
					clone_report(c,reports_to_statuses_hash)
				}
				## here we want to add the statuses.
				## rest of it deals with items, etc.
				add_tube_requirement({
					"item_requirement_name" => tube_type,
					"template_report_ids" => applicable_reports,
					"occupied_space" => required_amount,
					"patient_report_ids" => patient_report_ids
				})
			end
		end
	end

	def item_type_is_equivalent?(barcode,tube_type)
		item = Item.find(barcode)
		unless item.item_type == tube_type
			self.errors.add(:tubes, "tube type for this barcode : #{barcode} , does not match : #{tube_type}")
		end
		item.item_type == tube_type
	end

	def other_order_has_barcode?(barcode)
		puts "barcode is: #{barcode}"
		## and not self.
		results = Order.search({
			query: {
				nested: {
					path: "tubes",
					query: {
						term: {
							"tubes.barcode".to_sym => barcode
						}
					}
				}
			}
		})
		self.errors.add(:tubes, "This barcode #{barcode} has already been assigned to order id #{response.results.first.id.to_s}") if results.response.hits.hits.size > 0
		return true if results.response.hits.hits.size > 0
	end

	def delete_item_group(params)
		unless self.item_group_id.blank?
			if params[:item_group_id].blank?
				## clear the self item_group_id
				## 
			end
		end
	end
	
	def load_patient
		self.patient = Patient.find(self.patient_id)
		self.patient_name = self.patient.name
	end

	def get_patient_report_ids
		self.tubes.map{|c|
			c["patient_report_ids"]
		}.flatten.uniq
	end
	

	def generate_account_statement
		results = Status.search({
			sort: {
				created_at: {
					order: "asc"
				}
			},
			query: {
				bool: {
					must: [
							{
								bool: {
									should: [
										{
											term: {
												name: {
													value: "bill"
												}
											}
										},
										{
											term: {
												name: {
													value: "payment"
												}
											}
										}
									]
								}
							},
							{
								term: {
									order_id: {
										value: self.id.to_s
									}
								}
							},
							{
								terms: {
									report_id: get_patient_report_ids
								}
							}
					]
				}
			},
			aggs: {
				bills_and_payments: {
					terms: {
						field: "name",
						size: 100
					},
					aggs: {
				        by_id: {
					        terms: {
					            field: "_id",
					            size: 100
					        },
					        aggs: {
					        	amount: {
					        		terms: {
					        			field: "numeric_value",
					        			size: 1
					        		}
					        	},
					        	dates: {
					        		date_histogram: {
					        			field: "created_at",
					        			interval: "day"
					        		}
					        	},
					        	text_value: {
					        		terms: {
					        			field: "text_value",
					        			size: 1
					        		}
					        	}
					        }
				        },
				        total: {
				          	sum: {
				            	field: "numeric_value"
				          	}
				        }
				    }
				}
			}
		})

		self.account_statement = {bill: [], payment: [], pending: nil}

		total_bills = 0
		total_payments = 0

		results.response.aggregations.bills_and_payments.buckets.each do |bucket|
			curr_key = bucket["key"]
			unless bucket.by_id.buckets.blank?
				bucket.by_id.buckets.each do |status|
					unless status.amount.buckets.blank?
						id = status["key"]
						amount = status.amount.buckets.first["key"]
						date = status.dates.buckets.first["key_as_string"]
						text_value = status.text_value.buckets.first["key"]
						self.account_statement[curr_key.to_s.to_sym] << {id: id, amount: amount, date: date, text_value: text_value}
					end
				end
				if curr_key == "bill"
					total_bills = bucket["total"]["value"]
				elsif curr_key == "payment"
					total_payments = bucket["total"]["value"]
				end
			end
		end

		self.account_statement[:pending] = total_bills - total_payments

		puts "the account statement is:"
		puts JSON.pretty_generate(self.account_statement)

	end
	
end