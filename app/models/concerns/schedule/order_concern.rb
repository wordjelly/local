module Concerns::Schedule::OrderConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods
		  		
  		def add_to_aggregation(s,order,aggregation)
  			aggregation[s.id.to_s] = {
		      filter: {
		        nested: {
		          path: "employees",
		          query: {
		            bool: {
		              must: [
		                {
		                  term: {
		                    "employees.status_ids".to_sym => {
		                      value: s.id.to_s
		                    }
		                  }
		                },
		                {
		                  	nested: {
		                    path: "employees.bookings",
		                    query: {
		                      	bool: {
		                        must: [
		                          {
		                            range: {
		                              "employees.bookings.count".to_sym => {
		                                lte: s.maximum_capacity
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
		      },
		      aggs: {
		        minute: {
		          terms: {
		            field: "number",
		            size: 1,
		            order: [
		              {"current_order.doc_count".to_sym => "asc"},
		              {"other_orders.doc_count".to_sym => "asc"},
		              {"no_bookings.doc_count".to_sym => "asc"}
		            ]
		          },
		          aggs: {
		            current_order: {
			            filter: {
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
			            },
		              	aggs: {
		                	employees: {
		              			nested: {
		              				path: "employees"
		              			},
		              			aggs: {
		              				employee: {
		              					terms: {field: "employees.employee_id"},
		              					aggs: {
		              						bookings: {
			              						nested: {
			              							path: "employees.bookings"
			              						},
			              						aggs: {
			              							booking: {
			              								terms: {field: "employees.bookings.booking_id"}
			              							}
			              						}
		              						}
		              					}
		              				}
		              			}
		              		}
		                }
		            },
		            other_orders: {
		              	filter: {
		                	nested: {
			                  	path: "employees",
			                  	query: {
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
		                	}
		              	},
		              	aggs: {
		                	employees: {
		              			nested: {
		              				path: "employees"
		              			},
		              			aggs: {
		              				employee: {
		              					terms: {field: "employees.employee_id"},
		              					aggs: {
		              						bookings: {
			              						nested: {
			              							path: "employees.bookings"
			              						},
			              						aggs: {
			              							booking: {
			              								terms: {field: "employees.bookings.booking_id"}
			              							}
			              						}
		              						}
		              					}
		              				}
		              			}
		              		}
		                }
		            },
		            no_bookings: {
		              	filter: {
			                nested: {
			                  path: "employees",
			                  query: {
			                    bool: {
			                      must_not: [
			                        {
			                          exists: {
			                            field: "bookings"
			                          }
			                        }
			                      ]
			                    }
			                  }
			                }
		              	},
		              	aggs: {
		              		employees: {
		              			nested: {
		              				path: "employees"
		              			},
		              			aggs: {
		              				employee: {
		              					terms: {field: "employees.employee_id"}
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

		def add_to_query(query,status)
			query[:bool][:should] << 
				{
					bool: {
						must: [
							{
								range: {
									number: {
										gte: (status.from - 480),
										lte: (status.to + 480)
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
																"employees.status_ids".to_sym => status.id.to_s
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
																											lte: status.maximum_capacity
																										}
																									}
																								},
																								{
																									term: {
																										"employees.bookings.status_id".to_sym => status.id.to_s
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
																										"employees.bookings.status_id".to_sym => status.id.to_s
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
		end

		def add_to_booking(minute,employee_id,order_id,status,report_ids,remaining_capacity=0)
			update_script = 
			{
				script: {
					lang: "painless",
					inline: '''
					for(employee in ctx._source.employees){
						if(employee["employee_id"] == params.employee_id){
							Map booking = new HashMap();
							booking.put("report_ids",params.report_ids);
							booking.put("status_id",params.status_id);
							booking.put("order_id",[params.order_id]);

							Map prior_block = new HashMap();
							prior_block.put("minutes",params.block_minutes_prior);
							prior_block.put("remaining_capacity",0);
							prior_block.put("status_ids",[params.status_id]);
							prior_block.put("employee_ids",["*"]);

							Map subsequent_block_this_emp = new HashMap();
							subsequent_block_this_emp.put("minutes",params.block_minutes_hence);
							subsequent_block_this_emp.put("remaining_capacity",params.remaining_capacity);
							subsequent_block_this_emp.put("status_ids",["*"]);
							subsequent_block_this_emp.put("employee_ids",[params.employee_id]);

							Map subsequent_block_other_emp = new HashMap();
							subsequent_block_other_emp.put("minutes",params.block_minutes_hence);
							subsequent_block_other_emp.put("remaining_capacity",params.remaining_capacity);
							subsequent_block_other_emp.put("status_ids",[params.status_id]);
							subsequent_block_other_emp.put("employee_ids",[params.employee_id]);
							subsequent_block_other_emp.put("except",1);

							booking.put("blocks",[prior_block,subsequent_block_this_emp,subsequent_block_other_emp]);

				        	employee["bookings"].add(booking);
							employee["bookings_score"] = employee["bookings_score"] + 1;
							
						}
					}
					''',
					params: {
						block_minutes_prior: Array((minute - status.duration)..(minute)),
						reduce_prior_capacity_by: status.reduce_prior_capacity_by,
						block_minutes_hence: Array((minute)..(minute + status.duration)),
						employee_block_duration: status.employee_block_duration,
						minute: minute,
						employee_id: employee_id,
						order_id: order_id,
						report_ids: report_ids,
						status_id: status.id.to_s,
						remaining_capacity: remaining_capacity
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

		## all i have to do is sort this out today.
		def schedule_order(order)

			## QUERY FOR THE FREE MINUTES.
			query = {
				bool: {
					should: [
					]
				}
			}

			## AGG FOR THE FREE MINUTES.
			aggregation = {
				
			}


			## QUERY FOR THE BLOCKED_MINUTES
			blocks_query = Schedule::Block.query

			blocks_aggregation = {}

			## AGGREGATION FOR THE BLOCKED MINUTES.

			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					aggregation[status.id.to_s] = {}
					add_to_query(query,status)
					add_to_aggregation(status,order,aggregation)
					Schedule::Block.add_status_to_agg(blocks_aggregation,status)
				end
			end

			puts "the aggregation is"
			#puts JSON.pretty_generate(aggregation)
			puts JSON.pretty_generate(blocks_aggregation)

			search_result = Schedule::Minute.search({
				query: query,
				aggs:  aggregation
			})

			block_search_result = Schedule::Minute.search({
				query: blocks_query,
				aggs: blocks_aggregation
				#,
				#aggs: blocks_aggregation
			})


			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					status_id = status.id.to_s
					status_aggs = search_result.response.aggregations.send(status_id)		

					minute_buckets = get_minutes(status_aggs)
					minute_buckets.each do |bucket|


						minute_number = bucket["key"]
						
						if current_order?(bucket)
							#puts "current order detected"
							employee_id = get_employees(bucket.current_order).first["key"]	
							## add the booking.
							## to an employee.
							## is this a new booking.?
							## we want the booking id.
							## minute and employee.						
						elsif other_orders?(bucket)
							#puts "other order detected"
							## so now we have to build the block
							## here.
							employee_id = get_employees(bucket.other_orders).first["key"]
						else
							employee_id = get_employees(bucket.no_bookings).first["key"]
						end

						## now you send it to the blockage.
						puts "minute number: #{minute_number}"
						puts "employee id: #{employee_id}"

						## before this we would normally check the blocks.
						add_to_booking(minute_number,employee_id,order.id.to_s,status,["a","b","c"])

					end 

				end
			end

			flush_bulk
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