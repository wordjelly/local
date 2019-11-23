require 'elasticsearch/persistence/model'
require 'schedule/minute'
class Business::Order

	##################################################
	##
	##
	## ORDER OF ALL INCLUDES IS CRITICAL
	##
	##
	##################################################

	include Elasticsearch::Persistence::Model
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
  	include ActiveModel::Serialization

	index_name "pathofast-business-orders"
	document_type "business/order"
	## at this stage it has nothing.
	## that's why no callbacks are cascaded 
	## optimistacally.
	## and that's why this is probably getting fucked.
	## here you cascaded the callbacks.
	## or wherever
	## your issue is one of callback order.
	## 
	include Concerns::MissingMethodConcern
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::SearchOptionsConcern
	include Concerns::FormConcern
	include Concerns::Schedule::QueryBuilderConcern
	include Concerns::PdfConcern
	include Concerns::EsBulkIndexConcern
	## ORDER OF THESE TWO IS IMPORTANT.
	include Concerns::NotificationConcern
	include Concerns::OrderConcern
	## 
	include Concerns::CallbacksConcern
	## so the callbacks involve after find.
	## these should be execute first.
	## others can be done later.
	## that is one issue.



	after_save do |document|
		document.schedule
	end


	def schedule

		procedure_versions_hash = {}
		## let me sort this out first.
		## where is the start epoch.
		self.reports.each do |report|
			## so first by start time
			## then by procedure
			## and still fuse the queries

			## we consider the desired start time and the procedure, as a parameter for commonality.
			#puts "procedure version is:"
			#puts report.procedure_version
			#puts "report name is: "
			#puts report.name.to_s
			#puts "start epoch is:"
			#puts report.start_epoch
			l = report.procedure_version + "_"
			d = report.start_epoch.to_s + "_"
			effective_version = report.procedure_version + "_" + report.start_epoch.to_s
			if procedure_versions_hash[effective_version].blank?
				procedure_versions_hash[effective_version] =
				{
					statuses: report.statuses,
					reports: [report.id.to_s],
					start_time: report.start_epoch
				} 
			else
				procedure_versions_hash[effective_version][:reports] << report.id.to_s
			end
		end

		## give the statuses the :from and :to timings.
		procedure_versions_hash.keys.each do |proc|
			start_time = procedure_versions_hash[proc][:start_time]
			prev_start = nil
			procedure_versions_hash[proc][:statuses].map{|c|
				
				#puts "start time: #{start_time}"
				
				#puts "prev start: #{prev_start}"
				
				#puts "c duration: #{c.duration}"

				c.from = prev_start.blank? ? (start_time) : (prev_start + c.duration) 

				#puts "c from is: #{c.from}"

				c.to = c.from + Diagnostics::Status::MAX_DELAY
				prev_start = c.to
			}
		end
		self.procedure_versions_hash = procedure_versions_hash
		puts "the procedure versions hash is:"
		puts self.procedure_versions_hash.to_s
		Schedule::Minute.schedule_order(self)		
	end

	## do it from the statement.
	## make it as a part of the statement.
	## payments have to be queued -> then while making them.
	## it cannot be processed at the same time
	## or a lock on get_statement in redis
	## so if that fails -> it says please try again.
	## pay with balance -> lock balance (internal object)
	## Refresh index -> get statement -> check balance -> unlock balance
	## 

	## overriden this method to assign the name, as a bson id.
	## since the organization will already be fed in automatically
	def assign_id_from_name(organization_id)
		self.name ||= BSON::ObjectId.new.to_s
		if self.id.blank?
			unless self.name.blank?
				if organization_id.blank?	
					## this will happen for organization.		
					self.id = (BSON::ObjectId.new.to_s + "-" + self.name)
				else
					self.id = organization_id + "-" + self.name
				end
			end
		end
	end

	#########################################################
	##
	##
	## FORM CONCERN OVERRIDES
	##
	##
	#########################################################
	## now to figure out why the fuck the tabs are neither being 
	## seen nor working.
	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["outsourced_report_statuses","merged_statuses","search_options","procedure_versions_hash","latest_version","patient_id","template_report_ids","name"]
		}
	end

	## we add a hidden field called name.
	def customizations(root)

		customizations = {}
		
		if self.name.blank?
			customizations["name"] = '<input type="hidden" name="order[name]" value="' + BSON::ObjectId.new.to_s + '" />'
		else
			'<input type="hidden" name="order[name]" value="' + self.name.to_s + '" />'
		end

		customizations["do_top_up"] = '<a class="waves-effect waves-light btn" id="business_order_do_to_up_button"><i class="material-icons left">cloud</i>Do Top Up<input type="hidden" id="business_order_do_top_up" name="order[do_top_up]" value="' + Business::Order::NO.to_s + '" /></a>'
		
		## now comes the part about payments and locking
		## for the balance updates.
		## what happens to US stocks on a Monday
		## How do German stocks behave in October
		## What happens to Indian stocks when the temperature in London falls


		customizations
	end


	#########################################################
	##
	##
	## FORM CONCERN OVERRIDES END.
	##
	##
	#########################################################


	
end