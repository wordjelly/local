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
				type: 'integer'
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
	def self.get_blocked_mins(status)
		aggregation[status.id.to_s] = {
			filter: {
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
												"employees.bookings.blocks.status_id".to_sym => {
													"employees.bookings.blocks.status_ids".to_sym => [
					                                    status.id.to_s,
					                                    "*"
					                                ]
												}
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

end