require 'elasticsearch/persistence/model'
class Schedule::Routine < Schedule::Report
	include Elasticsearch::Persistence::Model
	attribute :is_routine, Integer, :default => 1

	## routine is actually a status
	## routine is a like a report
	## it will be attributed to many statuses
	## which are actually steps
	## routine is a job -> like clean the liver
	## and statuses have the steps in that.
	## routine can have a 
	## first lets create schedules
	## and block holidays
	## each schedule will have how many minutes ?
	## block certain days on the calendar
	## then we have to schedule empl
	## so basically is available from -> to
	## block from -> to
	## so you want to block.
	## default day working hours.
	## these can be defined 
	## for eg: satu, sund
	## each day will have many minutes
	## and we will have a generic day setter
	## we can also add employees to days.
	## so all schedules are in days onlhy.
	## if you want to add an employee, then 
	## so first basically only the days have to be created.
	## 
	## minute -> [employee ids]
	## now given the start time 
	## and we need the max end time.
	## okay so we have that.
=begin
	## minute -> [
	##	{
	##     employee_id:
	##     status_available:
	##     free_for_next_n_minutes:
 	##  } 
	##]
	## starting at 8.30 
	## look for a transport -> 
	## assuming transport is got immediately look 
	## match_all
	## with a max range
	## 8.30 -> 9.30
	## so then group by status id.
	## so we got n minute slots.
	## now.
	## take one, 
	## then we go to the next slot, 
	## take whatever you can get
	## then next slot.
	## then next.
	## and so on and so forth.
	## the wider you keep the range, the easier it will be to aggregate, but more time to aggregate.
	## so let's get the show on the road.
	## and then we just commit them.
	## as soon as possible.
	## handle delays better.
	## so how to schedule employees?
	## we do partial updates on minutes.
	## we will have to have a schedule object
	## it has many minutes
	## each minute is nested
	## it has to be created.
	## schedule has a start time and end time.
	## and many minute
	## lets imagine a calendar.
	## we choose a start date and an end date
	## we define holidays.
	## it looks for workers.
	## any change, and the whole schedule is rebooked.
	## get me the earlist minute that can do thsi status
	## so we got n.
	## then so let's say we extrapolated the times
	## and got availabilities
	## why not just reschedule those later on.
	## in an iterative fashion.
	## or say grouped by hours.
	## now we want to aggregate
	## filter by minute.
	## all those employess that can do between status
	## free for n minutes
	## aggregate by employee.
	## get earliest minute where
	## we have this status and free for minute is good enough,
	## 
=end
	## so we search -> 
	## every week
	## every year
	## every day
	## every monday
	## every tuesday
	## every month
	## routines are then gonna be alloted to people.
	## so people will have to have schedules.
	## which will get blocked.
	## we had gone down to minute level.
	## we need a minute to minute solving of this right ?
	## 
	## just wednesday
	## just today
	## just December -> goes to nearest december
	attribute :periodicity, String

	## how many times it is to be done on any given day.
	attribute :times, Integer

	## range of time when it is possible to start doing this in the day.
	attribute :start_time, Date

	## range of time when it is possible to end doing this in the day.
	attribute :end_time, Date

=begin
	attribute :schedules, type: "nested", properties: {
			start_time: {
				type: "date"
			},
			end_time: {
				type: "date"
			},
			action: {
				type: "keyword"
			},
			failed: {
				type: "keyword"
			}
	}
=end

	
end