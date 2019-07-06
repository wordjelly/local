module Concerns::Schedule::OrderConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods

  		OTHER_ORDERS = "other_orders"
  		CURRENT_ORDER = "current_order"
  		NO_BOOKINGS = "no_bookings"
  		CHAIN = [
			"blocked_minutes_filter",
			"employees",
			"back_to_minutes",
			"status_minute_range",
			"employee_again",
			"status_id_filter",
			"minute",
			"minute_histogram"
		]
  		####################################################
  		##
  		##
  		## SIMPLE QUERY AND AGGREGATION NO LONGER USED.
  		##
  		##
  		####################################################
		def simple_query(query,status,order)
			query[:bool][:should] << {
				bool: {
					must: [
						{
							range: {
								number: {
									lte: status.to,
									gte: status.from
								}
							}
						},
						{
							nested: {
								path: "employees",
								query: {
									bool: {
										must: [
											{
												term: {
													"employees.status_ids".to_sym => status.id.to_s
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
		end

		def simple_aggregation(statuses)
			agg = {}
			statuses.each do |status|
				agg[status.id.to_s] = {
					filter: {
						range: {
							number: {
								lte: status.to,
								gte: status.from
							}
						}
					},
					aggs: {
						employee_again: {
							nested: {
								path: "employees"
							},
							aggs: {
								status_id_filter: {
									filter: {
										term: {
											"employees.status_ids".to_sym => status.id.to_s
										}
									},
									aggs: {
										minute: {
											reverse_nested: {},
											aggs: {
												minute_histogram: {
													histogram: {
														field: "number",
														interval: status.duration/status.bucket_interval
													},
													aggs: {
														employee: {
															nested: {
																path: "employees"
															},
															aggs: {
																employee: {
																	terms: {field: "employees.employee_id", order: {minute: "asc"}, size: 1},
																	aggs: {
																		minute: {
																			min: {field: "employees.number"}
																		}
																	}
																},
																orders: {
																	nested: {
																		path: "employees.bookings"
																	},
																	aggs: {
																		order_filter: {
																			filter: {
																				term: {"employees.bookings.order_id".to_sym => "o1"}
																			},
																			aggs: {
																				emp: {
																					reverse_nested: {
																						path: "employees"
																					},
																					aggs: {
																						employee: {
																							terms: {field: "employees.employee_id", order: {minute: "asc"}, size: 1},
																							aggs: {
																								minute: {
																									min: {field: "employees.number"}
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
							}
						}
					}
				}
			end
			agg
		end
		####################################################
		##
		##
		## ENDS.
		##
		##
		####################################################

		## USED IN add_to_aggregation
		def other_orders_filter(order)
			{
				nested: {
	              	path: "employees",
	              	query: {
	              		bool: {
	              			must: [
	              				{
	              					nested: {
				                      	path: "employees.bookings",
				                      	query: {
					                        bool: {
					                          	must_not: [
						                            {
						                              	term: {
							                                "employees.bookings.order_id".to_sym => {
							                                  value: order.id.to_s
							                                }
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
	        	}
        	}
		end

		## USED In add_to_aggregation
		def current_order_filter(order)
			{
				nested: {
	                path: "employees",
	                query: {
	                    nested: {
	                      	path: "employees.bookings",
	                      	query: {
		                        term: {
		                          	"employees.bookings.order_id".to_sym => {
		                            	value: order.id.to_s
		                          	}
		                        }
	                      	}
	                    }
	                }
	            }
        	}
		end

		## USED in add_to_aggregation
		def no_bookings_filter
			{
				nested: {
	                path: "employees",
	                query: {
	                    nested: {
	                      	path: "employees.bookings",
	                      	query: {
	                      		bool: {
	                      			must_not: [
	                      				{
	                      					exists: {
					                        	field: "employees.bookings.status_id"
					                        }
	                      				}
	                      			]
	                      		}
	                      	}
	                    }
	                }
	            }
        	}
		end

		def add_to_query(query,status)
			query[:bool][:should] << 
				{
					bool: {
						must: [
							{
								range: {
									number: {
										gte: (status.from - 30),
										lte: (status.to + 30)
									}
								}
							}
						]
					}
				}
		end

		def add_to_aggregation(aggregation,status,order,blocked_minutes)
			## default blocked minute
			default_blocked_minutes = blocked_minutes[status.id.to_s] || [-1]
			aggregation[status.id.to_s] = {
				filters: {
					filters: {
						OTHER_ORDERS.to_sym => other_orders_filter(order),
						CURRENT_ORDER.to_sym => current_order_filter(order),
						NO_BOOKINGS.to_sym => no_bookings_filter
					}
				},
				aggs: {
					blocked_minutes_filter: {
						filter: {
							bool: {
								must_not: [
									terms: {
										"number".to_sym => default_blocked_minutes
									}
								]
							}
						},
						aggs: {
							employees: {
				      			nested: {
				      				path: "employees"
				      			},
				      			aggs: {	
		      						back_to_minutes: {
		      							reverse_nested: {},
		      							aggs: {
		      								status_minute_range: {
		      									filter: {
		      										range: {
		      											number: {
		      												gte: status.from,
		      												lte: status.to
		      											}
		      										}
		      									},
		      									aggs: {
			  										employee_again: {
			  											nested: {
			  												path: "employees"
			  											},
			  											aggs: {
			  												status_id_filter: {
			  													filter: {
			  														term: {
			  															"employees.status_ids".to_sym => status.id.to_s
			  														}
			  													},
			  													aggs: {
			  														minute: {
			  															reverse_nested: {},
			  															aggs: {
			  																minute_histogram: {
			  																	histogram: {
			  																		field: "number",
			  																		interval: status.duration/status.bucket_interval
			  																	},
			  																	aggs: {
			  																		employee: {
			  																			nested: {
			  																				path: "employees"
			  																			},
			  																			aggs: {
			  																				employee: {
			  																					terms: {field: "employees.number", size: 1},
																		      					aggs: {
																		      						employee_id: {
																		      							terms: {field: "employees.employee_id", size: 1},
																		      							aggs: {
																		      								bookings: {
																				          						nested: {
																				          							path: "employees.bookings"
																				          						},
																				          						aggs: {
																				          							booking: {
																				          								terms: {field: "employees.bookings.booking_id", size: 1}
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
		end

		## @param[Hashie::Mash] aggregation: the aggregation results for the given status
		## @param[Schedule::Status] status_object.
		## @param[Array: Schedule::Minute] booking_minutes_array : consists of minutes created to book, each minute contains one booking.
		## that is used in another function to build the bulk update script for making the bookings, and the capacities.
		## @param[Hash] status_durations : key -> duration, value -> [array of status ids]
		## so do we accept ?
		## as of now don't know what happens to the remaining tests, it can be that the lis only will run those many
		## and nothing more.
		## and the rest of the tests are rescheduled, for later
		## that way it can be done, but will have to work that outs
		## residual scheduling.
		## @return[Array] bookings_array : after adding the latest status to it.
		def status_aggregation_to_bookings(aggregation,status,booking_minutes_array,order,status_durations)
			
			last_minute = booking_minutes_array[-1]
			path = CHAIN.join(".")
			booked_minute = nil

			[CURRENT_ORDER,OTHER_ORDERS,NO_BOOKINGS].each do |option|
				if booked_min.blank?
					aggregation.send(option).send(path).buckets.each do |bucket|
						## booked_minute is defined in Concerns::Schedule::MinuteConcern, which is included in the Schedule::Minute class.
						booked_min = booked_minute(bucket,{
							order: order,
							status: status,
							booking_minutes_array: booking_minutes_array,
							status_durations: status_durations
						})
						unless booked_min.blank?
							booking_minutes_array << booked_min
							break
						end
					end
				end				
			end

		end

		## and what else will you do ?
		## all i have to do is sort this out today.
		def schedule_order(order)

			## BASE QUERY AND AGGREGATION
			query = { bool: { should: [] } }
			aggregation = {}

			
			blocks_result = {}

			
			order.procedure_versions_hash.keys.each do |pr|
				
				## first gotta merge this.
				## then status grouping.
				blocks_result[pr] = Schedule::Block.gather_blocks(order.procedure_versions_hash[pr][:statuses])
				
				order.procedure_versions_hash[pr][:statuses].each do |status|
					#simple_query(query,status,order)
					#so you filter the blocked minutes
					add_to_query(query,status)
					add_to_aggregation(aggregation,status,order,blocks_result)
				end
				#aggregation = simple_aggregation(order.procedure_versions_hash[pr][:statuses])
			end

			puts "the query is:"
			puts JSON.pretty_generate(query)
			IO.write("query.json", JSON.pretty_generate(query))

			puts "the aggregation is:"
			puts JSON.pretty_generate(aggregation)
			IO.write("aggregation.json", JSON.pretty_generate(aggregation))
			
			t = Time.now


			search_result = Schedule::Minute.search({
				size: 0,
				query: query,
				aggs:  aggregation
			})

			aggs = search_result.response.aggregations

			booking_minutes = []

			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					booking_minutes << status_aggregation_to_bookings(aggs.send(status.id.to_s),blocks_result[pr])
				end
			end

			booking_minutes.map{|c|
				update_request = {
					update: {
						_index: Schedule::Minute.index_name, _type: Schedule::Minute.document_type, _id: minute.number, data: c.update_script
					}
				}
				Schedule::Minute.add_bulk_item(update_request)
				c.employees.first.bookings.first.blocks.each do |block|
					Schedule::Bulk.add_bulk_item(block)
				end
			}		
			Schedule::Minute.flush_bulk	
			Schedule::Block.flush_bulk
			#flush_bulk
			t2 = Time.now

			puts "the base agg took: "
			puts (t2 - t)*1000
			exit(1)

		end
		#######################################################
		##
		##
		## CONVENIENCE METHODS FOR DEALING WITH THE AGG RESPONSE.
		##
		##
		#######################################################
		## @return[Array] array of buckets of each minute.
		def get_minutes(agg)
			agg.minute.buckets
		end

		## @return[Array] 
		def get_employees(bucket)
			puts "the bucket is:"
			puts JSON.pretty_generate(bucket)
			bucket.employees.employee.buckets
		end

		def current_order?(bucket)
			bucket.current_order.doc_count > 0
		end

		def other_orders?(bucket)
			bucket.other_orders.doc_count > 0
		end

	end
end