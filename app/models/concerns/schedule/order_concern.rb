module Concerns::Schedule::OrderConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods

  		def blocks_hash_to_query(employee_blocks_hash)
  			queries = []
  			employee_blocks_hash.keys.each do |employee_id|
  				queries << {
  					bool: {
  						must_not: [
  							{
  								terms: {
  									number: employee_blocks_hash[employee_id]
  								}
  							},
  							{
  								nested: {
  									path: "employees",
  									query: {
  										term: {
  											"employees.employee_id".to_sym => employee_id
  										}
  									}
  								}
  							}
  						]
  					}
  				}
  			end
  			queries
  		end


=begin

=end

		def filter__(employee_blocks_hash,s)
			{
  				bool: {
  					must: 
  					[
  						{
  							bool: {
  								must: blocks_hash_to_query(employee_blocks_hash)
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
  						}
  					]
  				}
		    }
		end

		def multi_filter(aggregation,status,order)
			aggregation[status.id.to_s] = {
				filters: {
					filters: {
						other_orders: other_orders_filter(order),
						current_order: current_order_filter(order)
					}
				},
				aggs: {
					employees: {
		      			nested: {
		      				path: "employees"
		      			},
		      			aggs: {
		      				filtered_employees: {
		      					filter: {
		      						bool: {
		      							must_not: [
		      								{
		      									terms: {
		      										"employees.id_minute".to_sym => ["0_0","1_0","2_0","3_0","4_0","5_0"]
		      									}
		      								}
		      							]
		      						}
		      					},
		      					aggs: {
		      						back_to_minutes: {
		      							reverse_nested: {},
		      							aggs: {
			  								minute: {
			  									terms: {
			  										field: "number"
			  									},
			  									aggs: {
			  										employee_again: {
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
			  								}
			  							}
		      						},
		      					}
		      				}
		      			}
		      		}
				}
			}
		end

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

=begin
		def other_orders
			filter: {
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
	      	},
	      	aggs: {
	        	employees: {
	      			nested: {
	      				path: "employees"
	      			},
	      			aggs: {
	      				filtered_employees: {
	      					filter: {
	      						bool: {
	      							must_not: [
	      								{
	      									terms: {
	      										"employees.id_minute".to_sym => ["0_0","1_0","2_0","3_0","4_0","5_0"]
	      									}
	      								}
	      							]
	      						}
	      					},
	      					aggs: {
	      						back_to_minutes: {
	      							reverse_nested: {}
	      						},
	  							aggs: {
	  								minute: {
	  									term: {
	  										field: "number"
	  									},
	  									aggs: {
	  										employee_again: {
	  											nested: {
	  												path: "employees"
	  											},
	  											aggs: {
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
	  									}
	  								}
	  							}
	      					}
	      				}
	      			}
	      		}
	        }
		end
=end
		

		def no_bookings

		end

  		## @param[Hash] employee_blocks_hash => 
  		def primary_aggregation(employee_blocks_hash,order,status)
  			{
	  			#filter: filter__(employee_blocks_hash,status),
			   	#aggs: {
			    #    minute: {
					  terms: {
					    field: "number",
					    size: 1,
					    order: [
					      {"blocked_filter>current_order.doc_count".to_sym => "asc"},
					      {"blocked_filter>other_orders.doc_count".to_sym => "asc"},
					      {"blocked_filter>no_bookings.doc_count".to_sym => "asc"}
					    ]
					  },
					  aggs: {
					  	blocked_filter: {
					  		filter: {
					  			nested: {
					  				path: "employees",
					  				query: {
					  					bool: {
					  						must_not: [
					  							{
					  								term: {
					  									"employees.id_minute".to_sym => "0_0"
					  								}
					  							}
					  						]
					  					}
					  				}
					  			}
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
							      	},
							      	aggs: {
							        	employees: {
							      			nested: {
							      				path: "employees"
							      			},
							      			aggs: {
							      				filtered_employees: {
							      					filter: {
							      						bool: {
							      							must_not: [
							      								{
							      									terms: {
							      										"employees.id_minute".to_sym => ["0_0","1_0","2_0","3_0","4_0","5_0"]
							      									}
							      								}
							      							]
							      						}
							      					},
							      					## reverse aggregation on the minutes
							      					## and then the employee id.
							      					## that can be simpler.
							      					## so we will automatically ignore
							      					## and we can sort this on the 
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
					#}
	  			#}
  			}
  		end

  		def add_to_aggregation(aggregation,s,order)
  			aggregation[s.id.to_s] = primary_aggregation({"0" => [0,1,2,3]},order,s)
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

			## first get the bloody aggregation working.
				
			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					aggregation[status.id.to_s] = {}
					add_to_query(query,status)
					multi_filter(aggregation,status,order)
					#add_to_aggregation(aggregation,status,order)
				end
			end

			puts "the aggregation is"
			puts JSON.pretty_generate(aggregation)
			#puts JSON.pretty_generate(blocks_aggregation)

			search_result = Schedule::Minute.search({
				query: query,
				aggs:  aggregation
			})



			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					status_id = status.id.to_s
					status_aggs = search_result.response.aggregations.send(status_id)		
					puts "the status aggs are:"
					puts JSON.pretty_generate(status_aggs)
					exit(1)
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