module Concerns::Schedule::QueryBuilderConcern

	extend ActiveSupport::Concern

  	included do

  		attr_accessor :global_statuses_hash

  		attr_accessor :global_minutes_hash

  		attr_accessor :status_queries_hash

  		## Hash
  		## structure :
  		## key -> status_id
  		## value -> Hash
  			## => key(status_id_from_to)
  			## => value (nil)
  		attr_accessor :open_status_ids_hash


  		## array [status_keys]
  		attr_accessor :open_status_keys_array

  	end

  	def build_statuses_hash(statuses,start_epoch,report)
  		
  		puts "Statuses going in are:"
  		puts statuses.to_s

  		prev_status_end = start_epoch

  		statuses.each do |status|

  			status.from = prev_status_end

  			status.to = Diagnostics::Status::MAX_DELAY + status.from
  			## each query is a hash 
  			## it consists of report ids
  			## and from and to keys.
  			from_to_combination = status.from.to_s + "_" + status.to.to_s

  			puts "the status id is: #{status.id.to_s}"
  			puts "the from to combination is: #{from_to_combination}"

  			if status_queries_hash[status.id.to_s].blank?
	  			status_queries_hash[status.id.to_s] ||= {
	  				blocks: [],
	  				queries: {
	  					(from_to_combination).to_sym => {
		  					from: status.from,
		  					to: status.to,
		  					report_ids: [report.id.to_s]
	  					}
	  				}
	  			}
	  		else
	  			if status_queries_hash[status.id.to_s][:queries][from_to_combination.to_sym].blank?
	  				status_queries_hash[status.id.to_s][:queries][from_to_combination.to_sym] = {
	  					from: status.from,
	  					to: status.to,
	  					report_ids: [report.id.to_s]
	  				}
	  			else
	  				status_queries_hash[status.id.to_s][:queries][from_to_combination.to_sym][:report_ids] << report.id.to_s
	  			end
  			end

  			status_key = status.id.to_s + "_" + from_to_combination
  			status_key = status_key.to_sym
  			
  			if self.global_statuses_hash[status_key].blank?
  				self.global_statuses_hash[status_key] = [report.id.to_s] 
  			else
  				self.global_statuses_hash[status_key] << report.id.to_s
  			end

  			Array((status.from)..(status.to)).each do |k|
				self.global_minutes_hash[k.to_i] ||= {}
				self.global_minutes_hash[k.to_i][status_key.to_sym] ||= []
				self.global_minutes_hash[k.to_i][status_key.to_sym] << report.id.to_s
  			end

  			prev_status_end = status.to

  		end

  	end

  	def build
  		 
  		prev_employee_capacity = nil
  		prev_minute_statuses = []
  		open_status_blocks = []
  		self.global_minutes_hash.keys.each do |minute|
  			required_employee_capacity = self.global_minutes_hash[minute].keys

  			if prev_employee_capacity.blank?
  				## open the blocks.
  				## for this status.
  				self.global_minutes_hash[minute].keys.each do |status_key|
					status_id = status_key.to_s.split("_")[0]
					block = {
						from: minute,
						to: nil,
						total_employee_capacity: required_employee_capacity
					}
					self.status_queries_hash[status_id.to_s][:blocks] << block
					open_status_blocks << status_id
				end
  				
  			else

  				puts "difference is:"
  				puts prev_minute_statuses - self.global_minutes_hash[minute].keys
  				 
	  			if (prev_minute_statuses - self.global_minutes_hash[minute].keys).size > 0

	  				open_status_blocks.each do |status_id|
	  					self.status_queries_hash[status_id.to_s][:blocks].map{|c|
	  						c[:to] = minute if c[:to].blank?
	  					}
	  				end

	  				open_status_blocks = []
	  			
	  			end

  			end

  			

  			prev_employee_capacity = required_employee_capacity
  			prev_minute_statuses = self.global_minutes_hash[minute].keys

  		end
  	end

=begin
  	def build
  		
  		prev_min_status_count = self.global_minutes_hash.values.first.size
  		
  		self.global_minutes_hash.keys.each do |minute|
  			
  			message("iterating",minute)

  			message(self.global_minutes_hash[minute],minute)
  				
  			keys_to_remove = []
  			
  			keys_to_add = []

  			new_keys = []

  			if self.open_status_ids_hash.blank?

  				message("open status ids hash is blank.",minute)
  				
  				self.global_minutes_hash[minute].keys.each do |status_key|
  				
  					message("doing status key: #{status_key}",minute)
  				
  					status_id = status_key.to_s.split("_")[0]
  				
  					message("status id is: #{status_id}",minute)
  				
  					#status_queries_hash[status_id.to_s][:blocks][status_key] ||= {}
  					
  					open_status(status_key,minute)
  					
  					keys_to_add << status_key

  				end

  			else
  				curr_min_status_count = self.global_minutes_hash[minute].keys.size
  				
  				message("curr min status count: #{curr_min_status_count}, prev min status count: #{prev_min_status_count}",minute)

  				if curr_min_status_count == prev_min_status_count
  					## close any missing keys
  					self.open_status_keys_array.each do |ok|
  						if global_minutes_hash[minute][ok].blank?
  							# we closed it here because 
  							close_status(ok,minute)

  							keys_to_remove << ok
  							# in this case there is no question of reopening. 
  						end
  					end
  				else
  					## open all the new keys.
  					new_keys = (self.global_minutes_hash[minute].keys - self.open_status_keys_array)

  					message("global minutes hash keys #{self.global_minutes_hash[minute].keys}",minute)
  					message("open status array keys: #{self.open_status_keys_array}",minute)
  					message("new keys: #{new_keys}",minute)

  					self.open_status_keys_array.each do |ok|
  						close_status(ok,minute)
  						# reopen if its key has a "to" component greater than this minute
  						upto = ok.to_s.split("_")[-1]
  						status_id = ok.to_s.split("_")[0]
  						if upto.to_i >= minute
  							## if you open it , it will overwrite.
  							## so you are opening for what exactly 
  							## for this key.
  							new_key = status_id + "_" + minute.to_s + "_" + upto.to_s
  							open_status(new_key,minute)
  							keys_to_add << new_key
  						else
  							keys_to_remove << ok
  						end
  					end

  					message("keys to remove: #{keys_to_remove}",minute)

  				end	

  				prev_min_status_count = curr_min_status_count

  			end

  			keys_to_remove.map{|c| self.open_status_keys_array.delete(c.to_s)}

  			keys_to_add.map{|c| self.open_status_keys_array << c.to_s}

  			message("opening status for new keys: #{new_keys}",minute)
  			new_keys.map{|c|
  				open_status(c,minute)
  				open_status_keys_array << c.to_s
  			}
  			message("End opening status",minute)
			
  		end
  	end
=end
  	## where will they add the reports
  	## how do they get outsourced ?
  	## 

  	def close_status(status_key,to)
  		status_id = status_key.to_s.split("_")[0]
  		puts "status key:#{status_key}"
  		puts "status id: #{status_id}"
  		puts status_queries_hash[status_id.to_s][:blocks]
  		status_queries_hash[status_id.to_s][:blocks][status_id.to_s][status_key.to_s][:to] = to
  		self.open_status_ids_hash[status_id].delete(status_key)
  		#self.open_status_keys_array.delete(status_key)
  	end

  	def open_status(status_key,from)
  		#message("opening status key: #{status_key}",from)
  		status_id = status_key.to_s.split("_")[0]
  		status_queries_hash[status_id.to_s][:blocks][status_id.to_s] ||= {}
  		status_queries_hash[status_id.to_s][:blocks][status_id.to_s][status_key.to_s] = 
  		{
			from: from,
			to: nil,
			total_employee_capacity: self.global_minutes_hash[from].keys.size
		}

		self.open_status_ids_hash[status_id] ||= {}
		
		self.open_status_ids_hash[status_id][status_key] ||= {}
		
		#self.open_status_keys_array << status_key
  	
  	end

  	def init
  		self.global_minutes_hash = {}
  		self.global_statuses_hash = {}
  		self.status_queries_hash = {}
  		self.open_status_ids_hash = {}
  		self.open_status_keys_array = []
  	end

  	def build_queries
  		init
  		self.reports.each do |report|	
  			build_statuses_hash((report.merged_statuses.blank? ? report.statuses : report.merged_statuses),report.start_epoch,report)
  		end

  		build
  		## so why is this not working.
  		puts " --------- status queries hash --------------- "
  		puts JSON.pretty_generate(self.status_queries_hash)

  		#puts " --------- global minutes hash --------------- "
  		#puts JSON.pretty_generate(self.global_minutes_hash)
  		## okay so gotta solve this shit out today
  		## so lets setup a simple scenario.
  		exit(1)
  	end

  	#########################################################
  	##
  	##
  	## DEBUG FUNCTIONS
  	##
  	##
  	#########################################################
  	def message(info,minute)
  		if ((minute.to_i >= 510) && (minute.to_i <= 511)) 
  			puts "#{minute}  --> : #{info}"
  		end
  	end

end