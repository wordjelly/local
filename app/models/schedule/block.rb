require 'elasticsearch/persistence/model'
class Schedule::Block
	include Elasticsearch::Persistence::Model
	include Concerns::EsBulkIndexConcern
	include Concerns::Schedule::BlockConcern

	index_name "pathofast-schedule-blocks"
	document_type "schedule/block"

	## number of minutes , before and after the 
	BLOCK_SEARCH_OFFSET = 300

	attribute :from_minute, Integer, mapping: {type: 'integer'}
	attribute :to_minute, Integer, mapping: {type: 'integer'}
	attribute :minutes, Array, mapping: {type: 'integer'}
	attribute :status_ids, Array, mapping: {type: 'keyword'}
	attribute :employee_ids, Array, mapping: {type: 'keyword'}
	attribute :remaining_capacity, Integer, mapping: {type: 'integer'}
	## number of samples that can be performed, on any of the minutes in the block.
	attribute :sample_capacity, Integer, mapping: {type: 'integer'}
	## number of employees that are available on any minute of the block.
	attribute :employee_capacity, Integer, mapping: {type: 'integer'}

	## it will be lat and lon
	attribute :location, Hash

	def self.index_properties
		{
			minutes: {
				type: 'integer'
			},
			status_ids: {
				type: 'keyword'
			},
			except: {
				type: 'integer'
			},
			employee_ids: {
				type: 'keyword'
			},
			remaining_capacity: {
				type: 'integer'
			},
			sample_capacity: {
				type: 'integer'
			},
			employee_capacity: {
				type: 'integer'
			},
			location: {
				type: 'geo_point'
			}
		}
	end

	####################################################
	##
	##
	## METHODS TO BUILD THE QUERY AND AGGREGATION
	## TO FIND THE BLOCKS, WHILE SCHEDULING THE ORDER.
	##
	##
	####################################################
	def self.block_range_clause(status)

		{
			lte: status.to + Schedule::Block::BLOCK_SEARCH_OFFSET,
			gte: status.from - Schedule::Block::BLOCK_SEARCH_OFFSET
		}

	end

	## total employee capacity, has to be gte the number
	## you may need.
	## 

	## @return[Hash] : blocked_minutes_per_status : 
	## {
	##   status_id => [blocked_minute1,blocked_minute2]
	## }
	def self.gather_blocks(statuses)
		blocked_minute_per_status = {}
		nearby_statuses = {}
		statuses.map{|c|
			unless c.origin.blank?
				nearby_statuses[(c.id.to_s + "_nearby").to_sym] = {
					geo_distance: {
						field: "employees.bookings.blocks.location",
						origin: c.origin,
						unit: "km",
						ranges: [
							{
								to: 3
							}
						]
					}
				}
			end
		}

		query_and_aggregation = 
		{
			size: 0,
			query: {
				match_all: {}
			},
			aggs: {
				status_ids: {
					nested: {
						path: "employees"
					},
					aggs: {
						status_ids: {
							nested: {
								path: "employees.bookings"
							},
							aggs: {
								status_ids: {
									nested: {
										path: "employees.bookings.blocks"
									},
									aggs: {
										status_ids: {
											terms: {
												field: "employees.bookings.blocks.status_ids",
												include: statuses.map{|c| c.id.to_s}
											},
											aggs: {
												minutes: {
													terms: {
														field: "employees.bookings.blocks.minutes",
														size: 100
													},
													aggs: {
														capacities: {
															sum: {
																field: "employees.bookings.blocks.sample_capacity"
															}
														},
														zero_minutes: {
															bucket_selector: {
																buckets_path: {
																	tcap: "capacities"
																},
																script: "params.tcap < 1"
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

		query_and_aggregation[:aggs][:status_ids][:aggs][:status_ids][:aggs][:status_ids][:aggs][:status_ids][:aggs][:minutes][:aggs].merge!(nearby_statuses)

		# unless externally defined
		# it is the organization.
		# so we will provide an adapter.
		# at the order level.
		# so we have the coordinates
		#aggs,status_ids,aggs,status_ids,aggs,status_ids,aggs,status_ids
		#puts "the blocks query is:"
		#puts JSON.pretty_generate(query_and_aggregation)
		search_request = Schedule::Minute.search(query_and_aggregation)


		#puts "--------------- blocks aggregation------------------ "
		#puts JSON.pretty_generate(blocked_minute_per_status)
		#puts JSON.pretty_generate(search_request.response.aggregations)
		#return blocked_minute_per_status if search_request.response.aggregations.status_ids.status_ids.blank?
		if search_request.response.aggregations.status_ids.status_ids.blank?
			#puts "it is blank"
		else
			search_request.response.aggregations.status_ids.status_ids.status_ids.status_ids.buckets.each do |s_bucket|
				status_id = s_bucket["key"]
				blocked_minutes = s_bucket.minutes.buckets.map{|c| c["key"]}
				#puts "blocked minutes are:"
				#puts blocked_minutes.to_s
				blocked_minute_per_status[status_id] = blocked_minutes
				
			end
		end
		#exit(1)
		#puts JSON.pretty_generate(blocked_minute_per_status)
		#exit(1)
		## but that can be the same statuses repeating
		## as well
		## so it could get repeated
		blocked_minute_per_status
	end

=begin 
	def self.status_filters(statuses)
		agg = {}
		## create a fresh block document
		## [1-45], blocks [status_id-9], by 1
		## 
		statuses.each do |status|
			agg[status.id.to_s] = {
				terms: {
					field: "employees.bookings.blocks.status_ids",
					include: [status.id.to_s]
				},
				aggs: {
					minute: {
						reverse_nested: {},
						aggs: {
							minute: {
								terms: {field: "number"}
							}
						}
					}
				}
			}
		end
		agg
	end

	def self.simple_aggregation(statuses)
		{
			capacity_filter: {
				filter: {
					nested: {
						path: "employees",
						query: {
							nested: {
								path: "employees.bookings",
								query: {
									nested: {
										path: "employees.bookings.blocks",
										query: {
											bool: {
												must: [
													{
														terms: {
															"employees.bookings.blocks.status_ids".to_sym => statuses.map{|c| c.id.to_s}
														}
													}
												]
											}
										}
									}
								}
							}
						}
					}
				},		
				aggs:{
					status_agg: {
						nested: {
							path: "employees"
						},
						aggs: {
							status_agg: {
								nested: {
									path: "employees.bookings"
								},
								aggs: {
									status_agg: {
										nested: {
											path: "employees.bookings.blocks"
										},
										aggs: status_filters(statuses)
									}
								}
							}
						}
					}
				}
			}
		}
	end

	def self.add_to_aggregation(aggregation,status)
		#employees.bookings.blocks.status_related.
		aggregation[status.id.to_s] = {
			filter: {
				range: {
					number: block_range_clause(status)
				}
			},
			aggs: {
				employees:
				{
					nested: {
						path: "employees"
					},
					aggs: {
						bookings: {
							nested: {
								path: "employees.bookings"
							},
							aggs: {
								blocks: {
									nested: {
										path: "employees.bookings.blocks"
									},
									aggs: {
										status_related: {
											filter: {
												terms: {
													"employees.bookings.blocks.status_ids".to_sym => [
						                                    status.id.to_s,
						                                    "*"
						                                ]
													
												}
											},
											aggs: {
												blocked_minutes: {
													terms: {
														field: "employees.bookings.blocks.minutes"
													},
													aggs: {
														has_capacity: {
															filter: {
																range: {
																	"employees.bookings.blocks.remaining_capacity".to_sym => {
																		lte: 0
																	}
																}
															},
															aggs: {
																back_to_minute: {
																	reverse_nested: {path: "employees"},
																	aggs: {
																		blocked_employee_minute: {
																			terms: {
																				field: "employees.employee_id"
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

	def self.add_to_query(query,status)
		query[:bool][:should] << {
			bool: {
				must: [
					{
						range: {
							number: block_range_clause(status)
						}
					},
					{
						nested: {
							path: "employees",
							query: {
								nested: {
									path: "employees.bookings",
									query: {
										nested: {
											path: "employees.bookings.blocks",
											query: {
												bool: {
													must: [
														{
															terms: {
																"employees.bookings.blocks.status_ids".to_sym => [status.id.to_s,"*"]
															}
														},
														{
															range: {
																"employees.bookings.blocks.remaining_capacity".to_sym => {
																	lte: 0
																}
															}
														}
													]
												}
											}
										}
									}
								}
							}
						}
					}
				]
			}
		}
	end

	def self.blocks_hash_to_query(employee_blocks_hash)
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
=end
  	

end