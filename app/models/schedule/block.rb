require 'elasticsearch/persistence/model'
class Schedule::Block
	include Elasticsearch::Persistence::Model
	index_name "pathofast-schedule-bookings"
	document_type "schedule/booking"

	attribute :from_minute, Integer, mapping: {type: 'integer'}
	attribute :to_minute, Integer, mapping: {type: 'integer'}
	attribute :minutes, Array, mapping: {type: 'integer'}
	attribute :statuse_ids, Array, mapping: {type: 'keyword'}
	attribute :employee_ids, Array, mapping: {type: 'keyword'}
	attribute :remaining_capacity, Integer, mapping: {type: 'integer'}

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
				type: 'keyword'
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

	def self.query 
		{
			bool: {
				must: [
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
	end

	def self.agg_pre_filter(status)
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
									terms: {
	                                  "employees.bookings.blocks.status_ids".to_sym => [
	                                    status.id.to_s,
	                                    "*"
	                                  ]
	                                }
								}	
							}
						}
					}
				}
			}
		}
	end

	def self.agg_capacity(status)

=begin
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

					}
				}
			}
		}
=end

		{
			#employees: {
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
									blocked_minutes: {
										terms: {
											field: "employees.bookings.blocks.minutes"
										},
										aggs: {
											"minimum_remaining_capacity".to_sym => {
												min: {
													field: "employees.bookings.blocks.remaining_capacity"
												}
											}
										}
									}
								}
							}
						}
					}
				}
			#}
		}

	end

	def self.add_status_to_agg(aggregation,status)
		aggregation[status.id.to_s.to_sym] = agg_capacity(status)
	end

end