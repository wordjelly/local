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
	include Concerns::LocationConcern
	## ORDER OF THESE TWO IS IMPORTANT.
	include Concerns::NotificationConcern
	include Concerns::OrderConcern
	## 
	include Concerns::CallbacksConcern
	include Concerns::BackgroundJobConcern
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
			"*" => ["outsourced_report_statuses","merged_statuses","search_options","procedure_versions_hash","latest_version","patient_id","template_report_ids","name","pdf_urls","visit_type_tags","recipients","disable_recipient_ids","resend_recipient_ids","owner_ids","changed_for_lis","created_by_user_id","currently_held_by_organization","public","ready_for_pdf_generation","ready_to_send_notification","trigger_lis_poll","bill_outsourced_reports_to_patient","bill_outsourced_reports_to_order_creator","created_at","updated_at","images_allowed","order_completed"]
		}
	end

	def non_array_attributes_card_title
		self.patient.full_name + " tests "
	end

	def accessors_to_render
		["force_pdf_generation"]
	end

	## we add a hidden field called name.
	def customizations(root)

		customizations = {}
		
		if self.name.blank?
			customizations["name"] = '<input type="hidden" name="order[name]" value="' + self.patient.name.to_s + "tests" + '" />'
		else
			'<input type="hidden" name="order[name]" value="' + self.patient.name.to_s + "tests" + '" />'
		end

		customizations["do_top_up"] = '<div style="display:none;"><a class="waves-effect waves-light btn" id="business_order_do_to_up_button"><i class="material-icons left">cloud</i>Do Top Up<input type="hidden" id="business_order_do_top_up" name="order[do_top_up]" value="' + Business::Order::NO.to_s + '" /></a></div>'
			
		#######################################################
		##
		##
		## FOR PDF URL
		##
		##
		#######################################################
		if self.pdf_url.blank?
			customizations["pdf_url"] = '<i class="material-icons">warning</i>Report Not Yet Available'
		else
			customizations["pdf_url"] = '<a href="' + self.pdf_url + '"><i class="material-icons">insert_drive_file</i>Report PDF</a>'
		end

		customizations["pdf_url"] += '<input type="hidden" name="order[pdf_url]" value="' + self.pdf_url.to_s + '" />'

		#######################################################
		##
		##
		##
		## FOR ADD OUTSOURCED ORGANIZATION
		##
		##
		#######################################################
		if self.outsourced_by_organization_id.blank?
			customizations["outsourced_by_organization_id"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;">If the sample has come from another lab, type lab name here<input id="business_order_outsourced_by_organization_id"  name="order[outsourced_by_organization_id]" data-autocomplete-type="organizations" data-use-id="yes" type="text"></div>'
		else
			customizations["outsourced_by_organization_id"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;">Outsourced From: ' + self.outsourced_by_organization_id + '<input id="business_order_outsourced_by_organization_id"  name="order[outsourced_by_organization_id]" data-autocomplete-type="organizations" data-use-id="yes" type="hidden" value="' + self.outsourced_by_organization_id + '"></div>'
		end
		

		#######################################################
		##
		##
		##
		## FOR FINALIZE ORDER
		##
		##
		#######################################################
		## REPORT FORMATS -> WITHOUT ANY ERROS (WE ARE STILL IN TROUBLE)
		## UI FOR THE TUBES, REPORT ADDING, PROFILES
		## we also want to show the twenty most common reports.
		## which can be easily chosen
		## and a profile option.
		## we need some profiles.
		## so order finalization -> will be done -> adding tubes a simplified UI for that,
		## adding a simplified input for the history questions and checking that interpretation
		## finalizating remaining report formats.
		## making profiles possible.
		## and packages with discount coupons.
		##tracking of payments from outsourced organization -> so that we can start that at least
		## and rate masking.
		if self.can_be_finalized.blank?
			customizations["finalize_order"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;"><input type="hidden" id="business_order_finalize_order" name="order[finalize_order]" value="' + Business::Order::NO.to_s + '" /></a>Add some reports/tests to continue</div>'
		elsif self.can_be_finalized == "true"
			if self.finalize_order == YES
				customizations["finalize_order"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;"><input type="hidden" id="business_order_finalize_order" name="order[finalize_order]" value="' + Business::Order::NO.to_s + '" /></a>This order has already been finalized</div>'
			else
				customizations["finalize_order"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;"><a class="waves-effect waves-light btn-small" id="business_order_finalize_order_button">Finalize Order<input type="hidden" id="business_order_finalize_order" name="order[finalize_order]" value="' + Business::Order::NO.to_s + '" /></a></div>'
			end
		else
			customizations["finalize_order"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;">' + self.can_be_finalized + '<input type="hidden" id="business_order_finalize_order" name="order[finalize_order]" value="' + Business::Order::NO.to_s + '" /></div>'
		end
		#######################################################
		##
		##
		##
		## FOR COLLECTION PACKET
		##
		##
		##
		#######################################################
		if self.local_item_group_id.blank?
			customizations["local_item_group_id"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;">If you have a Pathofast Collection Kit, add its barcode number here.<input id="business_order_local_item_group_id"  name="order[local_item_group_id]" type="text"></div>'
		else
			customizations["local_item_group_id"] = '<div style="margin-top: 1rem; margin-bottom: 1rem; border: 1px solid; padding:1rem;">Collection Packet Barcode:' + self.local_item_group_id + '.<span id="change_local_item_group_id">Click here to change it</span><input style="display:none;" id="business_order_local_item_group_id"  name="order[local_item_group_id]" value="' + self.local_item_group_id + '" type="text"></div>'
		end

		#######################################################
		##
		##
		## FOR REGENERATE PDF
		##
		##
		#######################################################
		customizations["force_pdf_generation"] = '<div><input type="hidden" id="business_order_force_pdf_generation" name="order[force_pdf_generation]" value="' + Business::Order::NO.to_s + '" /><br><a class="waves-effect waves-light btn-small" id="force_pdf_generation_button">Generate Latest Report PDF</a></div>'

		#######################################################
		##
		##
		##
		## SHOW THE REPORTS ALREADY ADDED
		## and the button to add more.
		## on clicking rest is in js.
		##
		##
		#######################################################
=begin
		customizations["simplify_report_adding"] = '<div><a class="waves-effect waves-light btn-small" id="add_reports_button">Add Reports</a>
			<div id="add_reports_details" style="display:none;">
				<p>
			      <label>
			        <input id="show_outsourced" type="checkbox" />
			        <span>Outsource</span>
			      </label>
			    </p>
			    <p>
			      <label>
			        <input id="show_packages" type="checkbox" />
			        <span>Show Packages</span>
			      </label>
			    </p>
			    <a class="waves-effect waves-light btn-small" id="show_reports_list">Show Reports List</a>
			    <span>If the report is not seen in the list, go to the search bar above and search for the report, then click choose</span>
			    <div id="report_choices_holder">
			    	<table style="max-height:200px; overflow-y: scroll; display:block;">
			    		<thead>
			    			<th>Report Name</th>
			    			<th>Outsource To Organization</th>
			    			<th>Status</th>
			    		</thead>
			    		<tbody id="reports_list_holder">
			    		</tbody>
			    	</table>
			    </div>
			</div>
			</div>'
=end
		## this and then the tubes.
		## and the test editing.
		## that's all we have to manage today.

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