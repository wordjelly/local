module Concerns::StatusConcern

	extend ActiveSupport::Concern

	included do 
		
		attr_accessor :statuses
		attr_accessor :status_names

		after_find do |document|
			load_statuses
		end

		def load_statuses
			results = Status.search({
				sort: {
					created_at: {
						order: "desc"
					}
				},
				query: {
					term: {
						parent_ids: self.id.to_s
					}
				}
			})
			self.statuses = []
			self.statuses = results.response.hits.hits.map{|c|
				s = Status.new(c._source)
				s.id = c._id
				s
			}
			
		end

		## so how do we do the reverse application
		## status says ok ->
		## for this status what is the primary tube
		## i.e status is em200 -. 
		## tube is x 
		## registered reports are y
		## reports that can be done on em200 are z
		## tube priority for these reports each is as follows
		## if you hit a secondary priority, then ask which tests
		## otherwise update status for these reports only.
		## so we set this where exactly ?
		## item_Requirement has report ids.
		## so there we set also for that report -> 
		## where it can be done.
		## or on report.
		## machine codes.
		## em-200, xpand
		## e411
		## or we have a machine model, and put report ids there.
		## status -> has a machine name -> gets the machine code -> ## gets the test -> gets the tests on tube(1st priority) -> checks which can be performed.
		## machine can also have statuses
		## like machine is down.
		## we call it equipment.
		## we can also have status updates about current loads on that machine.
		## so first we make a new model called equipment.
		## then proceed.

	end

end