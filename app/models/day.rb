require 'elasticsearch/persistence/model'
class Day



	## today finish schedule, day and employee
	## tomorrow finish equipment interaction, status updating.
	## day after report generation, normal ranges, and pdf creation
	## sunday -> doctor registration and all his orders and cocoare
	## monday -> amazon cognito, and user permissions integration.
	## if we can get this done, we are through.

	include Elasticsearch::Persistence::Model
	include Concerns::EsBulkIndexConcern
	
	index_name "pathofast-days"

	attribute :date, Date

	attribute :working, Integer, :default => 1

	attribute :minutes, Array[Hash]

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
		    indexes :minutes, type: 'nested', properties: {
			    	number: {
						type: "integer"
					},
					working: {
						type: "integer"
					},
					## give a default to booked_Status_id as -1
					employees: {
						type: "nested",
						properties: {
							employee_id: {
								type: "keyword"
							},
							status_ids: {
								type: "keyword"
							},
							booked_status_id: {
								type: "keyword"
							},
							booked_duration: {
								type: "integer"
							},
							booked_count: {
								type: "integer"
							}
						}
					}
		    	}
	    end
	end

	## UI for day
	## UI for employee
	## all this goes through day only.
	## UI to see schedules
	## UI for equipment for tube priority
	## UI for controls, and interfacing the new equipment, sorting out interfacing issues for the older equipment.


	############################################3
	##
	##
	## UTILITY TEST METHODS
	##
	##
	#############################################
	def self.bulk_size
		10
	end

	
	def self.create_test_days
		status_ids = []    	
    	
    	100.times do |status|
    		status_ids << status
    	end

    	days = []
    	    	
    	100.times do |day|
    		d = Day.new(id: "day_" + day.to_s)
    		d.date = Time.now + day.days
    		d.working = 1
    		d.minutes = []
    		720.times do |minute|
    			m = {}
    			m[:number] = minute
    			m[:working] = 1
    			m[:employees] = []
    			6.times do |employee|
    				e = {}
    				e[:employee_id] = employee
    				e[:status_ids] = status_ids
    				e[:booked_status_id] = -1
    				e[:booked_count] = 0
    				m[:employees] << e
    			end
    			d.minutes << m
    		end
    		puts d.as_json.to_s
    		Day.add_bulk_item(d)

    	end
    	Day.flush_bulk
	end	


end