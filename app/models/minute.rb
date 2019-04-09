require 'elasticsearch/persistence/model'
class Minute
	include Elasticsearch::Persistence::Model
	include Concerns::EsBulkIndexConcern
	
	index_name "pathofast-minutes"

	attribute :date, Date
	attribute :working, Integer, :default => 1
	attribute :number, Integer
	attribute :employees, Array[Hash]


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
							}
						}
					}
				}
	    end
	end

	## so now we have order, patient report ids, and tube ids, in every minute
	## so we can search by either of these
	## if we remove some template reports
	## then what about the tubes ?
	## if the barcode is blank?
	## 

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
		Minute.search({
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
										path: "bookings"
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
																		path: "bookings"
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

		## then we update those minutes with scripts
		## after this removal from minutes
		## if a barcode is wrongly entered.
		## we only add newer ones.
		## how to remove one that does not exist anymore ?
		## if we add a new barcode to the tubes
		## we would check the reports, 
		## and then we would add this barcode.
		## so we will have to send in all the barcodes.
		## and if none of them is there, it will have to be removed
		## when a report is removed, it has to be deleted from
		## any minute where it exists, in any booking.
		## these two things can be handled easily

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
	def self.create_single_test_minute(status)
		status_ids = [status.id.to_s]
		m = Minute.new(number: 1, working: 1, employees: [], id: 1.to_s)
		1.times do |employee|
			e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
			m.employees << e
		end
		Minute.add_bulk_item(m)
		Minute.flush_bulk
	end


	## creates a single minute, with 
	## creates n minutes.
	def self.create_two_test_minutes(status)
		status_ids = [status.id.to_s]
		2.times do |n| 
			m = Minute.new(number: n, working: 1, employees: [], id: n.to_s)
			1.times do |employee|
				e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
				m.employees << e
			end
			Minute.add_bulk_item(m)
		end
		Minute.flush_bulk
	end

	def self.create_test_minutes(number_of_minutes)
		status_ids = []    	
    	5.times do |status|
    		status_ids << status.to_s
    	end
		number_of_minutes.times do |minute|
			m = Minute.new(number: minute, working: 1, employees: [], id: minute.to_s)
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
			Minute.add_bulk_item(m)
		end
		Minute.flush_bulk
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
    			m = Minute.new(number: minute_count, working: 1, employees: [], id: minute_count.to_s)
    			6.times do |employee|
    				e = Employee.new(id: employee.to_s, status_ids: status_ids, booked_status_id: -1, booked_count: 0)
    				m.employees << e
    			end
    			minute_count+=1
    			Minute.add_bulk_item(m)
    		end
    	end
    	Minute.flush_bulk
	end	



	def self.aggregate_employee_bookings(employee_id,minute_from,minute_to)
		## so let's get this working first. of all.
		search_results = Minute.search({
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

				Minute.add_bulk_item(update_hash)

			end

			Minute.flush_bulk

		end

	end



	## @param[String] date : block and reallot from
	## @param[String] date : block and reallot to
	## @param[String] employee_id : the employee to be blocked
	## @param[Array] status_ids : defaults to an empty array, which means all statuses.
	def self.block_status(from,to,status_id,employee_ids=[])

	end

	## @param[Array] required_statuses: 
	## each status must have
	## :from => an integer (minutes from epoch)
	## :to => an integer (minutes from epoch)
	## :id => the id of the status 
	## :maximum_capacity => an integer, the maximum number of these statuses that can be done at any given minute
	## @return[Hash]
=begin
	{
		status_id => {
			minute_id => {
				employee_ids => []
			}
		}
	}
=end
	def self.get_minute_slots(args)
		
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
									gte: c[:from],
									lte: c[:to]
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

		puts "the queries are:"
		puts JSON.pretty_generate(query)

		query_and_aggs = 
			{
				query: query,
			  	aggs: {
			    	required_status: {
			      		nested: {
			        	path: "employees"
			      	},
			      	aggs: {
			        	status_id: {
				          		terms: {
				            		field: "employees.status_ids",
				            		size: 10,
				            		include: args[:required_statuses].map{|c| c[:id]}
				          		},
				          		aggs: {
				            		minute: {
				              			reverse_nested: {},
				              			aggs: {
				                			minute_id: {
				                  				terms: {
				                    				field: "number",
				                    				order: {"_key".to_sym => "asc"}
				                  				},
				                  				aggs: {
					                    			employees: {
						                      			nested: {
						                        			path: "employees"
						                      			},
						                      			aggs: {
						                        			emp_id: {
						                          				terms: {
						                            				field: "employees.employee_id",
						                            				size: 10,
						                            				order: {
						                              					bookings_score: "asc"
						                            				}
						                         				},
						                          				aggs: {
						                            				bookings_score: {
							                              				min: {
							                                				field: "employees.bookings_score"
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

		response = search(query_and_aggs)

		## this is not working, because number is not here.
		##puts response.response.hits.hits.to_s
		##puts response.response.aggregations.required_status.to_s
		status_results = {}
		response.response.aggregations.required_status.status_id.buckets.each do |status_id_bucket|
			status_id = status_id_bucket["key"]
			status_results[status_id] = {}
			status_id_bucket.minute.minute_id.buckets.each do |minute_bucket|
				minute = minute_bucket["key"]
				employee_ids = minute_bucket.employees.emp_id.buckets.map{|c|
					c["key"]
				}
				status_results[status_id][minute] = employee_ids
			end
		end

		status_results

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


	def self.build_minute_update_request_for_order(
		order_statuses_hash,order)
		prev_status_minute = nil
		prev_status_id = nil
		## this count is the problem.
		## how many have to be assigned herewith.
		## 
		order_statuses_hash.keys.each do |status|
			status_obj = Status.find(status)
			report_ids = order.get_patient_report_ids_applicable_to_status(status_obj)
			status_duration = status_obj.duration
			status_count = report_ids.size
			employee_block_duration = status_obj.employee_block_duration
			block_other_employees = status_obj.block_other_employees

			if prev_status_minute.blank?
				start_minute = order_statuses_hash[status].keys[0]
			else
				viable_minutes = order_statuses_hash[status].keys.select{|c|
					c >= (prev_status_minute + status_duration)
				}
				unless viable_minutes.blank?
					start_minute = viable_minutes[0]

				end
			end

			employee_id = order_statuses_hash[status][start_minute][0]

			update_request = {
				script: {
					lang: "painless",
					inline: '''
						for(employee in ctx._source.employees){
					        if(employee["id"] == params.employee_id){
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
					''',
					params: {
						employee_id: employee_id,
						order_id: order.id,
						status_id: status,
						report_ids: report_ids,
						count: status_count
					}		
				}
			}

			update_request = {
				update: {
					_index: index_name, _type: document_type, _id: start_minute, data: update_request
				}
			}


			add_bulk_item(update_request)

			employee_block_duration.times do |k|

				## for each employee here,
				## for the block duration
				if block_other_employees == 1
					puts "block other employees"
					## in this case, 
					## it means that no one else can do this statust till the end.
					## as well as this employee
					## its basically a status block.
					request_details = {
						script: {
							lang: "painless",
							inline: '''
								for(employee in ctx._source.employees){
							        employee.status_ids.remove(params.status)
							      }
							''',
							params: {
								status_id: status
							}		
						}
					}

					## here we don't do k + 1.
					## here we do only
					update_request = {
						update: {
							_index: index_name, _type: document_type, _id: (start_minute + k).to_s, data: request_details
						}
					}

					add_bulk_item(update_request)

				end

				## we basically make the employee ineligible for these statuses.
				puts "got that we have to block the employee in subsequent minutes."

				request_details = {
					script: {
						lang: "painless",
						inline: '''
							for(employee in ctx._source.employees){
								if(employee["id"] == params.employee_id)
						        employee.bookings_score = 11;
						      }
						''',
						params: {
							status_id: status,
							employee_id: employee_id
						}		
					}
				}

				puts "start minute + k is: #{start_minute + k}"

				update_request = {
					update: {
						_index: index_name, _type: document_type, _id: (start_minute + k + 1).to_s, data: request_details
					}
				}

				add_bulk_item(update_request)
			end


			prev_status_minute = start_minute
			prev_status_id = status
		end

		flush_bulk
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