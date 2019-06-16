require 'elasticsearch/persistence/model'
class Schedule::Minute
	include Elasticsearch::Persistence::Model
	include Concerns::EsBulkIndexConcern
	
	index_name "pathofast-schedule-minutes"
	document_type "schedule/minute"


	attribute :date, Date
	attribute :working, Integer, :default => 1
	attribute :number, Integer
	attribute :employees, Array[Hash]

	## we have to work with copy_to 
	## and we have to work with 
	## so we have the all field concern.
	## add that to all the models.
	## via a concern.
	## then do copy_to wherever you need it.

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
			indexes :employees, type: 'nested', 
				properties: {
					employee_id: {
						type: "keyword"
					},
					status_ids: { 
						type: "keyword"
					},
					bookings_score: {
						type: "float"
					},
					bookings: {
						type: "nested",
						properties: {
							status_id: {
								type: 'keyword'
							},
							count: {
								type: 'integer'
							},
							priority: {
								type: 'float'
							},
							order_id: {
								type: 'keyword'
							},
							report_ids: {
								type: 'keyword'
							},
							max_delay: {
								type: 'keyword'
							},
							tubes: {
								type: 'keyword'
							},
							blocks: {
								type: 'nested',
								properties: {
									minutes: {
										type: 'integer'
									},
									status_ids: {
										type: 'keyword'
									},
									employee_ids: {
										type: 'keyword'
									},
									remaining_capacity: {
										type: 'keyword'
									}
								}
							}
						}
					}
				}
	    end
	end

	## so we are storing the statuses in the minutes
	## at booking and employee levels.
	## so that is the main issue.
	## so if a report has certain steps.
	## they need to be reflected in a status
	## let that be a nested commonality.
	## it will be simpler like that.
	## so now we have order, patient report ids, and tube ids, in every minute
	## so we can search by either of these
	## if we remove some template reports
	## then what about the tubes ?
	## if the barcode is blank?
	## so we go for a method called update status capacities
	## where we update the previous minutes, as remaining capacity.
	def self.update_tube_barcode(report_ids,barcode)
		## we want those minutes
		## where the report ids is there
		## but the tube barcode is not seen.
		## and go and update it there.
		## in the agg we want to have the employee id, under that minute
		## where the report ids are found.
		## so we know we have to go and update that minute.
		## i could just go with inner hits.
		## can i combine this in one query ?
		## like for different barcodes.
		search_results = Schedule::Minute.search({
			query: {
				nested: {
					path: "employees",
					query: {
						nested: {
							path: "employees.bookings",
							query: {
								bool: {
									must: [
										{
											terms: {
												"employees.bookings.report_ids".to_sym => report_ids
											}
										},
										{
											bool: {
												must_not: [
													{
														term: {
															"employees.bookings.tubes".to_sym => barcode
														}
													}
												]
											}
										}
									]
								}
							}
						}
					}
				}
			},
			aggs: {
				minutes: {
					terms: {
						field: "_id"
					},
					aggs: {
						employees: {
							nested: {
								path: "employees"
							},
							aggs: {
								employee_ids: {
									nested: {
										path: "employees.bookings"
									},
									aggs: {
										bookings_with_reports: {
											filter: {
												terms: {
													"employees.bookings.report_ids".to_sym => report_ids
												}
											},
											aggs: {
												back_to_employees: {
													reverse_nested: {
														path: "employees"
													},
													aggs: {
														employee_ids: {
															terms: {
																field: "employees.employee_id"
															},
															aggs: {
																back_to_bookings: {
																	nested: {
																		path: "employees.bookings"
																	},
																	aggs: {
																		booking_priority: {
																			min: {
																				field: "employees.bookings.priority"
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
								}
							}
						}
					}
				}
			}
		})

		minute_hash = {}	

		search_results.response.aggregations.minutes.buckets.each do |minute_bucket|
			
			minute_id = minute_bucket["key"]
			minute_hash[minute_id] = {}
			minute_bucket.employees.employee_ids.bookings_with_reports.back_to_employees.employee_ids.buckets.each do |employee_id_bucket|
				employee_id = employee_id_bucket["key"]
				bookings_priority = employee_id_bucket.back_to_bookings.booking_priority["value"]
				#puts "the employee id bucket is:"
				#puts employee_id_bucket.to_s
				#puts "the bookings priority is:"
				#puts bookings_priority.to_s
				minute_hash[minute_id][employee_id] = bookings_priority.to_i
			end

		end

		build_minute_update_requests_for_tube(minute_hash,barcode)

		flush_bulk

	end

	## once the tubes are added, they have to be updated to the relevant minutes
	## in another background job;
	## this is because they are added in a seperate request.

	## so the script will check the existing bookings.
	## these we already have to have.
	## we do it one day at a time.
	## it gets assigned to multiple people.
	## do we aggregate?
	## the time can be very large
	## we want the bookings of this person
	## it could also happen for a routine.
	## we can't reassing it to everyone.
	## i mean so we iterate
	## we come to that employee
	## we take the status ids, already booked
	## or we can do it in bunches.
	## of 100 minutes
	## aggregate existing bookings of this employee
	## group by minute
	## same minute get the least occupied employee
	## and in the update script, reassoign to them.
	## both possibilities can be done.
	def self.bulk_size
		100
	end

	## creates a single minute, with 
	## creates n minutes.
	def self.create_single_test_minute(status,employee_count=1)
		status_ids = [status.id.to_s]
		m = Schedule::Minute.new(number: 1, working: 1, employees: [], id: 1.to_s)
		employee_count.times do |employee|
			e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
			m.employees << e
		end
		Schedule::Minute.add_bulk_item(m)
		Schedule::Minute.flush_bulk
	end

	def self.create_multiple_test_minutes(total_mins,employee_count,status_ids,start_minute = 0)
		total_mins.times do |min|
			m = Schedule::Minute.new(number: (min + start_minute), working: 1, employees: [], id: (min + start_minute).to_s)
			employee_count.times do |employee|
				e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
				m.employees << e
			end
			Schedule::Minute.add_bulk_item(m)
		end
		Schedule::Minute.flush_bulk
	end


	## creates a single minute, with 
	## creates n minutes.
	def self.create_two_test_minutes(status)
		status_ids = [status.id.to_s]
		2.times do |n| 
			m = Schedule::Minute.new(number: n, working: 1, employees: [], id: n.to_s)
			1.times do |employee|
				e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
				m.employees << e
			end
			Schedule::Minute.add_bulk_item(m)
		end
		Schedule::Minute.flush_bulk
	end

	def self.create_test_minutes(number_of_minutes)
		status_ids = []    	
    	5.times do |status|
    		status_ids << status.to_s
    	end
		number_of_minutes.times do |minute|
			m = Schedule::Minute.new(number: minute, working: 1, employees: [], id: minute.to_s)
			6.times do |employee|
				e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: [0,1,2,3,4,5,6,7,8,9,10].sample)
				[0,1,2,3,4].sample.times do |booking|
					b = Booking.new
					b.status_id = status_ids.sample
					b.count = 2
					b.priority = booking
					b.order_id = "o#{booking}"
					b.report_ids = ["r#{booking}"]
					b.max_delay = 10*booking
					e.bookings << b		
				end
				m.employees << e
			end
			Schedule::Minute.add_bulk_item(m)
		end
		Schedule::Minute.flush_bulk
	end
	
	def self.create_test_days
		status_ids = []    	
    	100.times do |status|
    		status_ids << status
    	end
    	days = []
    	minute_count = 0
    	100.times do |day|
    		d = Day.new(id: "day_" + day.to_s)
    		d.date = Time.now + day.days
    		d.working = 1
    		d.minutes = []
    		720.times do |minute|
    			m = Schedule::Minute.new(number: minute_count, working: 1, employees: [], id: minute_count.to_s)
    			6.times do |employee|
    				e = Employee.new(id: employee.to_s, status_ids: status_ids, booked_status_id: -1, booked_count: 0)
    				m.employees << e
    			end
    			minute_count+=1
    			Schedule::Minute.add_bulk_item(m)
    		end
    	end
    	Schedule::Minute.flush_bulk
	end	



	def self.aggregate_employee_bookings(employee_id,minute_from,minute_to)
		## so let's get this working first. of all.
		search_results = Schedule::Minute.search({
			_source: false,
			query: {
				nested: {
					path: "employees",
					query: {
						bool: {
							must: [
								{
									term: {
										"employees.employee_id".to_sym => employee_id
									}
								},
								{
									nested: {
										path: "employees.bookings",
										query: {
											exists: {
												field: "employees.bookings"
											}
										}
									}
								}
							]
						}
					}
				}
			},
			aggs: {
				minute: {
					terms: {
						field: "_id"
					},
					aggs: {
						targeted_employee_bookings: {
							nested: {
								path: "employees"
							},
							aggs: {
								this_employee: {
									filter: {
										term: {
											"employees.employee_id".to_sym => employee_id
										}
									},
									aggs: {
										this_employee_bookings: {
											nested: {
												path: "employees.bookings",
											},
											aggs: {
												order_id: {
													terms: {
														field: "employees.bookings.order_id"
													},
													aggs: {
														status_id: {
															terms: {
																field: "employees.bookings.status_id"
															}
														},
														report_ids: {
															terms: {
																field: "employees.bookings.report_ids"
															}
														},
														priority: {
															terms: {
																field: "employees.bookings.priority"
															}
														},
														count: {
															terms: {
																field: "employees.bookings.count"
															}
														},
														max_delay: {
															terms: {
																field: "employees.bookings.max_delay"
															}
														}
													}
												}
											}
										}
									}
								},
								least_booked_employee: {
									terms: {
										field: "employees.employee_id",
										exclude: [employee_id],
										order: {
											"employee_bookings_score".to_sym => "desc"
										}
									},
									aggs: {
										"employee_bookings_score".to_sym => {
											min: {
												field: "employee.bookings_score"
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

		reallotment_hash = {}

		search_results.response.aggregations.minute.buckets.each do |minute_bucket|
			minute = minute_bucket["key"]
			bookings = []
			minute_bucket.targeted_employee_bookings.this_employee.this_employee_bookings.order_id.buckets.each do |order_id_bucket|
				booking = {}
				booking[:order_id] = order_id_bucket["key"]
				booking[:status_id] = order_id_bucket.status_id.buckets[0]["key"]
				booking[:count] = order_id_bucket["count"].buckets[0]["key"]
				booking[:report_ids] = order_id_bucket.report_ids.buckets[0]["key"]
				booking[:priority] = order_id_bucket.priority.buckets[0]["key"]
				bookings << booking
			end

			reallot_to_employee = nil

			if minute_bucket.targeted_employee_bookings.least_booked_employee.buckets.size > 0
				reallot_to_employee = minute_bucket.targeted_employee_bookings.least_booked_employee.buckets[0]["key"]
			end

			reallotment_hash[minute] = {reallot_to: reallot_to_employee, bookings: bookings}

		end

		reallotment_hash

	end

	## @param[String] date : block and reallot from
	## @param[String] date : block and reallot to
	## @param[String] employee_id : the employee to be blocked
	## @param[Array] status_ids : defaults to an empty array, which means all statuses.
	def self.block_and_reallot_bookings(from,to,employee_id,status_ids=[])

		minute_ids = get_minutes_ids(from,to)

		minute_ids.each_slice(100) do |minutes|

			reallotment_hash = aggregate_employee_bookings(employee_id,minutes.first,minutes.last)

			reallotment_hash.keys.each do |minute_id|

				update_hash = build_minute_update_request_for_reallotment(reallotment_hash.merge(:employee_to_block => employee_id))

				Schedule::Minute.add_bulk_item(update_hash)

			end

			Schedule::Minute.flush_bulk

		end

	end



	## @param[String] date : block and reallot from
	## @param[String] date : block and reallot to
	## @param[String] employee_id : the employee to be blocked
	## @param[Array] status_ids : defaults to an empty array, which means all statuses.
	def self.block_status(from,to,status_id,employee_ids=[])

	end

	## @param[Hash] s : status has.
	## expected to have a symbol key called :id
	def self.employee_agg(s)
		employee_agg = {
			employee_id: {
				terms: {
					field: "employees.employee_id",
					size: 1,
					order: {workload: "asc"}
				},
				aggs: {
					workload: {
						min: {
							field: "employees.bookings_score"
						}
					},
					status_bookings: {
						nested: {
							path: "employees.bookings"
						},
						aggs: {
							this_status: {
								filter: {
									term: {
										"employees.bookings.status_id".to_sym => s[:id]
									}
								},
								aggs: {
									booking_priority: {
										terms: {
											field: "employees.bookings.priority",
											order: {"_key".to_sym => "asc"}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	end

	## @args[Hash] : hash of arguments
	## 1.required_statuses: 
	## each status must have
	## :from => an integer (minutes from epoch)
	## :to => an integer (minutes from epoch)
	## :id => the id of the status 
	## :maximum_capacity => an integer, the maximum number of these statuses that can be done at any given minute
	## the number of reports that we have to set for this status.
	## that should be set on the status itself.
	## and after this we can easily calculate and set retrospective bookings.
	## 2. order_id
	## @return[Hash]
=begin
	{
		status_id => {
			minute_id => {
				bookings_priority => []
			}
		}
	}
=end

	## so we autocomplete on what exactly ?
	## each status can have a name ?
	## so we autocomplete on it 
	## 

	def self.minute_blocked(status_id,employee_id,minute,blocked_minutes_hash)
		false if blocked_minutes_hash[status_id].blank?
		false if blocked_minutes_hash[status_id][minute].blank?
		blocked_minutes_hash[status_id][minute].include? employee_id
	end


	def self.get_blocked_statuses_hash(args)

		query = {
			bool: {
				must: [
					{
						range: {
							number: {
								gte: (args[:required_statuses][0][:from] - 480),
								lte: (args[:required_statuses][0][:to] + 480)
							}
						}
					},
					{
						nested: {
							path: "employees",
							query: {
								nested: {
									path: "employees.bookings",
									query: {
										exists: {
											field: "employees.bookings.blocks"
										}
									}
								}
							}
						}
					}
				]
			}
		}

		aggs[:employees] = {
			nested: {
				path: "employees"
			},
			aggs: {
				employee_bookings: {
					nested: {
						path: "employees.bookings"
					},
					aggs: {
						employee_bookings_blockings: {
							nested: {
								path: "employees.bookings.blocks"
							},
							aggs: {
								these_statuses: {
									filter: {
										terms: {
											"employees.bookings.blocks.status_ids".to_sym => required_statuses.map{|c| c["id"]}
										}
									},
									aggs: {
										by_status: {
											terms: {
												field: "employees.bookings.blocks.status_ids"
											},
											aggs: {
												remaining_capacity: {
													min: {field: "employees.bookings.blocks.remaining_capacity"}
												},
												by_minute: {
													terms: {
														field: "employees.bookings.blocks.minutes"
													},
													aggs: {
														by_employee_id: {
															terms: {
																field: "employees.bookings.blocks.employee_ids"
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
				}
			}
		}

		search_result = Schedule::Minute.search({
			query: query,
			aggs:  aggs
		})

		blocked_minutes_hash = {}

		search_results.response.aggregations.block.employees.employees_bookings.employees_bookings_blockings.these_statuses.by_status.buckets.each do |status_bucket|
				status_id = status_bucket["key"]
				blocked_minutes_hash[status_id] = {}
				## add the remaining capacity for this status.
				
				status_bucket.by_minute.buckets.each do |minute_bucket|
					minute = minute_bucket["key"]
					blocked_minutes_hash[status_id][minute] = []
					minute_bucket.by_employee_id.buckets.each do |employee_bucket|
						employee_id = employee_bucket["key"]
						blocked_minutes_hash[status_id][minute] << employee_id
					end
				end
		end
		
		## status already has duration.
		## we need lot size.
		## and we need.

		blocked_minutes_hash
	end


	def self.get_minute_slots(args)
			
		## to be used in the prospective and retrospective blocking 
		## part.
		statuses_and_durations = Status.group_statuses_by_duration

		## so assuming that we have a certain capacity for a status
		## what needs to be done is that that capacity has to be reduced
		## for all employees for subsequent minutes.
		## somehow have to factor capacities into this.
		## so we have to aggregate by lot_size also.
		order = Business::Order.find(args[:order_id])

		query = {
			bool: {
				should: [

				]
			}
		}

		args[:required_statuses].map{|c|
			query[:bool][:should] << {
				bool: {
					must: [
						{
							range: {
								number: {
									gte: (c[:from] - 480),
									lte: (c[:to] + 480)
								}
							}
						},
						{
							bool: {
								must: [
									nested: {
										path: "employees",
										query: {
											bool: {
												must: [
													{range: {"employees.bookings_score".to_sym => {lte: 10}}},
													{
														term: {
															"employees.status_ids".to_sym => c[:id]
														}
													},
													{
														bool: {
															minimum_should_match: 1,
															should: [
																{
																	bool: {must_not: {exists: {field: "employees.bookings"}}}
																},
																{   
																	nested: {
																	path: "employees.bookings",
																	query: {
																		bool: {
																			minimum_should_match: 1,
																			should: [

																				{
																					bool: {
																						must: [
																							{
																								range: {
																									"employees.bookings.count".to_sym => 
																									{
																										lte: c[:maximum_capacity]
																									}
																								}
																							},
																							{
																								term: {
																									"employees.bookings.status_id".to_sym => c[:id]
																								}
																							}
																						]
																					}
																				},
																				{
																					bool: {
																						must_not: [
																							{
																								term: {
																									"employees.bookings.status_id".to_sym => c[:id]
																								}
																							}
																						]
																					}
																				}
																			]
																		}
																	}
																	}
																}
															]
														}
													}		
												]
											}
										}
									}
								]
							}
						}
					]
				}
			}
		}

		aggs = {
			
		}
		
		args[:required_statuses].each do |s|
			
			aggs[s[:id]] = {
				terms: {
					field: "number",
					size: s[:to] - s[:from],
					include: (s[:from].to_i..s[:to].to_i).to_a
				},
				aggs: {
					with_order_filter: {
						nested: {
							path: "employees"
						},
						aggs: {
							with_order_filter_bookings: {
								nested: {
									path: "employees.bookings"
								},
								aggs: {
									order_filter: {
										filter: {
											term: {
												"employees.bookings.order_id".to_sym => args[:order_id]
											}
										},
										aggs: {
											employees: {
												reverse_nested: {
													path: "employees"
												},
												aggs: employee_agg(s)
											}
										}
									}
								}
							}
						}
					},
					without_order_filter: {
						nested: {
							path: "employees"
						},
						aggs: employee_agg(s)
					}
				}
			}
		end

		query_and_aggs = 
		{
			query: query,
			aggs: aggs
		}

	
		search_results = search(query_and_aggs)
		blocked_minutes_hash = get_blocked_statuses_hash(args)
		#puts "these are the aggregations."
		#puts search_results.response.aggregations.to_s
		status_results = {}
		args[:required_statuses].each do |status|
			status_id = status[:id]
			status_results[status_id] = {}
			if !search_results.response.aggregations.send(status_id).blank?
				search_results.response.aggregations.send(status_id).buckets.each do |minute_bucket|
					minute = minute_bucket["key"]

					status_results[status_id][minute] = {
						:with_order => {},
						:without_order => {}
					}
					
					minute_bucket.with_order_filter.with_order_filter_bookings.order_filter.employees.employee_id.buckets.each do |eid|
							employee_id = eid["key"]
							## is this minute blocked for this status for this employee or not?
							unless minute_blocked(status_id,employee_id,minute,blocked_minutes_hash)

								status_results[status_id][minute][:with_order][employee_id] = []
								eid.status_bookings.this_status.booking_priority.buckets.each do |booking_priority_bucket|
									booking_priority = booking_priority_bucket["key"]
									status_results[status_id][minute][:with_order][employee_id] << booking_priority
								end

							end
						
					end

					minute_bucket.without_order_filter.employee_id.buckets.each do |eid|

						employee_id = eid["key"]
						unless minute_blocked(status_id,employee_id,minute,blocked_minutes_hash)

							status_results[status_id][minute][:without_order][employee_id] = []
							eid.status_bookings.this_status.booking_priority.buckets.each do |booking_priority_bucket|
								booking_priority = booking_priority_bucket["key"]
								status_results[status_id][minute][:without_order][employee_id] << booking_priority
							end

						end

					end

				end
			end
		end

		#puts status_results.to_s

		args[:required_statuses].each do |status|
				
			prev_end_minute = 0

			if status_results[status[:id]]
				existing_order_bookings = status_results[status[:id]].keys.select{|c|
					#puts "c is:"
					#puts c.to_s
					!status_results[status[:id]][c][:with_order].blank?
					#!c[:with_order].blank?
				}
				other_bookings = status_results[status[:id]].keys.select{|c| !status_results[status[:id]][c][:without_order].blank?}
				unless existing_order_bookings.blank?
					nearest_minute = get_best_minute(prev_end_minute,existing_order_bookings)
					#puts  "******************************************************"

					#puts "the nearest minute is:"
					#puts nearest_minute.to_s

					#puts "the nearest minute hash is:"
					#puts status_results[status[:id]][nearest_minute]

					#puts  "******************************************************"

					employee_id = status_results[status[:id]][nearest_minute][:with_order].keys[0]
					booking_priority = nil
					unless status_results[status[:id]][nearest_minute][:with_order][employee_id].blank?
						booking_priority = status_results[status[:id]][nearest_minute][:with_order][employee_id][0].to_s.to_i
					end
					build_update_script_for_booking(nearest_minute,employee_id,booking_priority,order.id.to_s,order.report_ids_to_add,status[:id])
					#block_previous_minutes(minute,status[:id])
					#block_subsequent_minutes(minute,status[:id])
				else
					nearest_minute = get_best_minute(prev_end_minute,other_bookings)
					#puts "other bookings nearest minute #{nearest_minute}"
					#puts other_bookings[nearest_minute].to_s
					employee_id = status_results[status[:id]][nearest_minute][:without_order].keys[0]	
					booking_priority = nil
					unless status_results[status[:id]][nearest_minute][:without_order][employee_id].blank?
						booking_priority = status_results[status[:id]][nearest_minute][:without_order][employee_id][0].to_s.to_i
					end	
					build_update_script_for_booking(nearest_minute,employee_id,booking_priority,order.id.to_s,order.report_ids_to_add,status[:id])			
				end

			else
			end
		end

		flush_bulk
	end

	def self.build_update_script_for_booking(minute,employee_id,booking_priority,order_id,report_ids,status_id)

		## status has
		## block_all_employees_from_starting_this_status
		## block_this_employee_from_starting_this_status
		## block_all_employees_from_starting_other_statuses
		## block_this_employee_from_starting_other_statuses
		## first we calculate for the present employee.
		## since he will not be able to do anything,
		## or any status, going back eight hours.
		## this will become a huge update, as it is minute 
		## wise.
		## status duration -> 100 minutes
		## status duration -> 200 minutes
		## any status which has 
		## status ordered by duration.
		## 2 minutes ->
		## 5 minutes ->
		## 10 minutes ->
		## 20 minutes -> (now minus 20 minutes - range, for all statuses, for this employee)
		## 30 minutes ->
		## 40 minutes ->
		## 50 minutes ->
		## 1 hour ->
		## 2 hours ->
		## whatever.
		## so we group the statuses like that.
		## and we institute blocks, backwards
		## and for other employees.
		## we will also have to derive the capacities
		## from the blocks.
		## okay so blocks, can be there, but with a remaining capacity
		## that way it can be done better.
		## so blocks, who all ?
		## all ,
		## with what 
		## how to add the capacities to this.
		## we have to block only this status.
		## right ?
		## for eg if i start doing a centrifuge.
		## no other employee can start doing a centrifuge.
		## for the duration of the centrifuge.
		## in the time it takes to complete one cycle.
		## here is where the question of capacities comes up.

		update_script = 
		{
			script: {
				lang: "painless",
				inline: '''
				for(employee in ctx._source.employees){
					if(employee["employee_id"] == params.employee_id){
						if(params.booking_priority == null){
							Map booking = new HashMap();
							booking.put("report_ids",params.report_ids);
							booking.put("status_id",params.status_id);
							booking.put("order_id",[params.order_id]);
					        booking.put("priority",employee.bookings.length);
				        	employee["bookings"].add(booking);
							employee["bookings_score"] = employee["bookings_score"] + 1;
						}
						else{
							for(booking in employee.bookings){
								if(booking["priority"] == params.booking_priority){
									booking["order_id"].add(params.order_id);
									booking["report_ids"].addAll(params.report_ids);
								}
							}
						}
					}
				}
				''',
				params: {
					minute: minute,
					employee_id: employee_id,
					booking_priority: booking_priority,
					order_id: order_id,
					report_ids: report_ids,
					status_id: status_id
				}	
			}
		}

		update_request = {
			update: {
				_index: index_name, _type: document_type, _id: minute, data: update_script
			}
		}

		add_bulk_item(update_request)
	end

	
	def self.get_best_minute(prev_end_minute,available_minutes)
		nearest_minute = available_minutes.select{|c| c >= prev_end_minute}
		if nearest_minute.blank?
			available_minutes[-1]
		else
			nearest_minute[0]
		end
	end

	#######################################################
	##
	##
	## we have a from and a to,
	## we have to convert it to an array of applicable minute
	## ids.
	## as long as that is in the open hours.
	## we go one minute at a time.
	##
	##
	#######################################################
	## we can define what is closed here.
	## for the moment it will check if hours of day of that day, are greater than 8.30 pm, or less than 8 am, then we 
	def self.is_closed?(time_obj)
		((time_obj.hour > 20) || (time_obj.hour < 8))
	end

	## @param[String] from : date
	## @param[String] to : date
	## @return[Array] minute_ids : array of strings each is basicaslly an integer, that represents the id of a minute object.
	def self.get_minutes_ids(from,to)
		minute_ids = []
		from_date = Time.new(from)
		to_date = Time.new(to)
		from_epoch = from_date.to_i
		to_epoch = to_date.to_i
		while(from_epoch < to_epoch)
			t = Time.at(from_epoch)
			unless is_closed?(t)
				minute_ids << (from_epoch/60).to_s
			end
			from_epoch+=60
		end
		minute_ids
	end

	## @param[String] id: valid id of a minute document to be updated
	## @param[Hash] params: MUST CONTAIN:
	## :employee_ids => array of valid employee ids.
	## :status_id => the id of the status that we are updating this minute with.
	## @return[Hash] : bulk update request hash. 
	def self.update_minute(id,params)

		update_request = {
			script: {
				lang: "painless",
				inline: '''
					for(employee_id in params.employee_ids){
				        def employee_found = 0;
				        for(employee in ctx._source.employees){
				            if(employee["id"] == employee_id){
				              employee_found = 1;
				              if(!employee["status_ids"].contains(params.status_id)){
				              	employee["status_ids"].add(params.status_id)
				              }
				            }
				        }
				        if(employee_found == 0){
				          Map obj = new HashMap();
				          obj.put("status_ids",[params.status_id]);
				          obj.put("id",employee_id);
				          obj.put("booked_status_id",-1);
				          obj.put("booked_count",0);
				          ctx._source.employees.add(obj);
				        }
				      }
				''',
				params: {
					employee_ids: params[:employee_ids],
					status_id: params[:status_id]
				}		
			}
		}

		{
			update: {
				_index: index_name, _type: document_type, _id: id, data: update_request
			}
		}


	end

	def self.build_minute_update_requests_for_tube(minute_hash,barcode)
		minute_hash.keys.each do |minute_id|
			minute_hash[minute_id].keys.each do |employee_id|

				update_script = {
					script: {
						lang: "painless",
						inline: '''
							for(employee in ctx._source.employees){
								
						        if(employee["id"] == params.employee_id){
						        	
						        	for(booking in employee.bookings){
						        		if(booking["priority"] == params.booking_priority){
						        			if(booking["tubes"] == null){
						        				booking["tubes"] = new ArrayList();
						        			}
							        		booking["tubes"].add(params.barcode);
						        		}
						        	}
						        }

						      }
						''',
						params: {
							employee_id: employee_id,
							booking_priority: minute_hash[minute_id][employee_id],
							barcode: barcode
						}		
					}
				}

				update_request = {
					update: {
						_index: index_name, _type: document_type, _id: minute_id, data: update_script
					}
				}

				add_bulk_item(update_request)

			end
		end
	end

	## @param[Hash] order_statuses_hash => 
	## @param[Business::Order] order =>
	## @param[Hash] args => contains a single key,
	## :required_statuses.
	def self.build_minute_update_request_for_order(
		order_statuses_hash,order,args)

	
		required_statuses = args[:required_statuses]

		prev_status_minute = nil
		prev_status_id = nil

		## if the first status is itself not there.
		## it doesn't matter, we piggyback in totum.

		puts "the order statuses hash."
		puts JSON.pretty_generate(order_statuses_hash)

		required_statuses.each do |status|
		
			puts "required status is"
			puts status.to_s
			## so how many things are registerd.
			## we want to say that 
			## if someone is already doing this status.
			## in a booking, then he should be doing it only 
			## once.
			## it should be the maximum capacity of that status.
			## that's the status count.
			## that's what we have to pass in.
			status_obj = Status.find(status[:id])
			report_ids = order.get_patient_report_ids_applicable_to_status(status_obj)
			status_duration = status_obj.duration
			status_count = report_ids.size
			employee_block_duration = status_obj.employee_block_duration
			block_other_employees = status_obj.block_other_employees
			bookings_priority = nil
			merge_order = 0
			start_minute = nil
			
			## so what is the problem here exactly ?


			last_minute = order_statuses_hash[status[:id]].keys.select{|c|
				order_statuses_hash[status[:id]][c].size > 1
			}
			unless last_minute.blank?
				last_minute = last_minute[-1]
			end
			order_statuses_hash[status[:id]].keys.each do |min|
				if order_statuses_hash[status[:id]][min].keys.size > 1
					if start_minute.blank?
						if prev_status_minute.blank?
							start_minute = min
							# here also set the booking priority
							# and employee id.
						else
							if min >= (prev_status_minute + status_duration)
								start_minute = minute
							end 
						end 
					end
				end
			end

			unless last_minute.blank?
				if start_minute.blank?
					start_minute = last_minute unless (last_minute <= prev_status_minute)
				end
			end

			unless start_minute.blank?
				employee_id = order_statuses_hash[status[:id]][start_minute][order_statuses_hash[status[:id]][start_minute].keys[0]][0]
				bookings_priority = order_statuses_hash[status[:id]][start_minute].keys[0]
				merge_order = 1
			else
				## here its already been chosen.
				## so we hook it onto the last minute.
				if prev_status_minute.blank?
					start_minute = order_statuses_hash[status[:id]].keys[0]
				else
					viable_minutes = order_statuses_hash[status[:id]].keys.select{|c|
						c.to_i >= (prev_status_minute.to_i + status_duration.to_i)
					}
					unless viable_minutes.blank?
						start_minute = viable_minutes[0]
					else
						## as long as the start minute is at least greater than the 
						## the previous status minute.
						puts "the status id is: #{status[:id]}"
						puts "the order statuses hash keys are"
						puts order_statuses_hash.keys.to_s
						start_minute = order_statuses_hash[status[:id]].keys[-1] if (order_statuses_hash[status[:id]].keys[-1].to_i >= prev_status_minute.to_i)
					end
				end

				unless start_minute.blank?
					employee_id = order_statuses_hash[status[:id]][start_minute]["-1"][0]
				end
			end


			if start_minute.blank?
				order.failed_to_schedule("could not find a start minute for status : #{status}")
				puts " - could not find a start minute -"
				exit(1)
				order.save
				return
			end


			update_request = {
				script: {
					lang: "painless",
					inline: '''
						for(employee in ctx._source.employees){
					        if(employee["id"] == params.employee_id){
					        	if(params.merge_order == 1){
					        		for(booking in employee.bookings){
					        			if(booking["priority"] == params.bookings_priority){
					        				booking["report_ids"].addAll(params.report_ids);
					        				booking["count"]+= params.report_ids.length;
					        			}	
					        		}
					        	}
					        	else{
						        	Map booking = new HashMap();
							        booking.put("report_ids",params.report_ids);
							        booking.put("status_id",params.status_id);
							        booking.put("order_id",params.order_id);
							        booking.put("count",params.count);
							        booking.put("priority",(employee.bookings.length));
						        	employee["bookings"].add(booking);
						        	employee["bookings_score"] = employee["bookings_score"] + 1;
					        	}
					        }

					      }
					''',
					params: {
						employee_id: employee_id,
						order_id: order.id,
						status_id: status[:id],
						report_ids: report_ids,
						count: status_count,
						merge_order: merge_order,
						bookings_priority: bookings_priority.to_i
					}		
				}
			}

			update_request = {
				update: {
					_index: index_name, _type: document_type, _id: start_minute, data: update_request
				}
			}

			puts "the update request is:"
			puts update_request.to_s

			add_bulk_item(update_request)

			prev_status_minute = start_minute
			prev_status_id = status
			start_minute = nil

		end

		flush_bulk

		order.scheduled_successfully

	end

	def self.build_minute_update_request_for_routine()

	end

	## @param[Hash] reallotment_details : A hash which contains, the following keys:
	## => reallot_to : [String] id of the employee to which to reallot
	## => bookings: [Array] the array of the bookings to push to the employee to reallot to
	## => employee_to_block : [String] id of the employee to be blocked.
	def self.build_minute_update_request_for_reallotment(reallotment_details)

		update_request = {
			script: {
				lang: "painless",
				inline: '''
			        for(employee in ctx._source.employees){
			            if(employee["id"] == params.employee_to_block){
			              employee.bookings = null;
			              employee.status_ids = null;
			            }
			        	else if(employee["id"] == params.reallot_to){
			        		for(booking in params.bookings){
			        			employee["bookings"].add(booking);
			        		}
			        	}
			        }
				''',
				params: reallotment_details
			}
		}

		{
			update: {
				_index: index_name, _type: document_type, _id: id, data: update_request
			}
		}

	end

end