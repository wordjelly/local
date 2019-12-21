module Concerns::OrderConcern

	extend ActiveSupport::Concern

	included do 
		
		YES = 1
		NO = -1

		#################################################
		##
		##
		## ORDER-> REPORT NOTIFICATION TWO FACTOR CONSTANTS
		##
		##
		##
		#################################################
		REPORT_UPDATED_TEMPLATE_NAME = "Report Updated"
		REPORT_UPDATED_SENDER_ID = "LABTST"


		################################################
		##
		##
		## VISIT TYPE TAGS
		##
		##
		################################################
		## visit_type_tags.
		attribute :visit_type_tags, Array[Tag], mapping: {type: 'nested', properties: Tag.index_properties}

		validates :visit_type_tags, length: {
		    maximum: 1,
		    message: 'Please choose only one visit type option'
		}

		## these are to be populated based on the visit type tag
		attr_accessor :visit_location_options
		###############################################
		##
		##
		##
		###############################################

		## now we go for updating the 

		## it should validate them for the name.
		## the length should be less than or equal to one.

		## SHOULD BE MADE TO 1 when ->
		## report is added or removed from an order
		## a requirement priority change is effected
		## see  -> requirement (category#top_priority)
		## whichever category is marked as top_priority will be used 
		## for all the tests in that report, and that will automatically
		## set changed_for_lis to 1.
		## this should ideally be a date
		## field, and reflect when it was last changed for the lis.
		## so we will sort this one out
		attribute :changed_for_lis, Date, mapping: {type: 'date', format: 'epoch_second'}

		attribute :trigger_lis_poll, Integer, mapping: {type: 'integer'}, default: NO

		attribute :name, String, mapping: {type: 'keyword'}

		attribute :reports, Array[Diagnostics::Report]

		attribute :patient_id, String, mapping: {type: 'keyword'}

		attr_accessor :patient

		attribute :categories, Array[Inventory::Category] 

		## this is not a permitted parameter actually.
		## payments is internally generated.
		## it actually consists of the bills.
		#attribute :payments, Array[Business::Payment]

		attribute :receipts, Array[Business::Receipt]
		## so we keep this different.
		## the payment is in its own index.
		## or it is in this index.
		## let us say we regenerate the bills each time.
		## it deletes everything called a bill.
		## and regenerates it.
		## 
		## a new report chosen is first added to these
		## then internally is used to load the relevant report
		## and populate the reports array.
		attribute :template_report_ids, Array, mapping: {type: 'keyword'}

		attribute :local_item_group_id

		attribute :procedure_versions_hash, Hash

		## this should be a custom button
		## in the display
		## if clicked, then it can be shown differently.
		attribute :do_top_up, Integer, mapping: {type: 'integer'}, default: NO

		## key -> user_id
		## value -> user object
		## @used_in : self in #group_reports_by_organization
		## used to make a hash of user objects
		## these are used in the pdf/show to render the signature and credentials 
		attr_accessor :users_hash

		## reports by organization
		attr_accessor :reports_by_organization

		###############################################
		##
		##
		## TESTS CHANGED BY LIS
		##
		##
		##
		###############################################
		## this accessor is set in self#update_lis_results , called from #interfaces_controller.rb#update_many
		## the idea is to store in an accessor which
		## tests have been successfully changed by the lis
		## after the bulk update, the orders are reloaded
		## and checked if those tests still hold the update
		## if they don't for any reason, then error is returned to the lab_local_server on that particular order, for that particular test.
		## structure
		## {lis_code => {org_id => value_updated}}
		attr_accessor :tests_changed_by_lis

		## so the location is a must
		## for any of this to work
		## but we have to have a way to load the nearest location
		## in case of that
		## first what about the location options
		## so it shows those locations.
		## to be chosen from -> before giving one to the order
		## depending on the other choice.
		## that has to be dynamically done.
		## so it will have to have something called location options 
		## so like an address or a location id.
		## so they are basically ?
		## location objects.
		## which are chosen once the tag is defined.
		## so after_find ?
		## ya after_find is a better idea.
		## we load the location options
		## they are basically ids ?
		## or an array of objects ?
		## only if a location is not already chosen.
		## is that a better idea ?
		## billing options should get merged.
		## if the tag changes ?
		## tags change -> then update the locations
		## chosen location -> order 
		## 
		##########################################################
		##
		##
		## 
		## BILLING OPTIONS
		##
		##
		##
		##########################################################

		

		#############################################
		##
		## Attributes of the exact same name are specified on the 
		## organization.
		##
		## IF the attributes here remain as null, then 
		## those attributes are used, i.e the defaults. 
		## so we make these permitted on order.
		##
		#############################################

		attribute :bill_outsourced_reports_to_patient, Integer, mapping: {type: 'integer'}

		attribute :bill_outsourced_reports_to_order_creator, Integer, mapping: {type: 'integer'}


		## reports by organization
		attr_accessor :bills_by_organization

		#####################################################
		##
		##
		## HISTORY TAGS
		##
		##
		#####################################################
		## structure
		## key -> tag_id
		## value -> Tag
		## 
		## built_in : self#build_history_tags
		attr_accessor :history_tags



		####################################################
		##
		##
		## FOR THE PDF JOB TO BE GIVEN(IN THE AFTER SAVE CALLBACK)
		##
		## POPULATE IN AFTER_VALIDATION -> IN THE GENERATE_RECEIPT_PDFS, AND THE process_pdf.
		## 
		##
		#####################################################
		## step one -> get the job working.
		## step two -> get the notification sending code working
		## it should email the link to the pdf.
		## that's the main target for the notifications.
		## and step -> 3 -> the reminder notifications
		## time based triggering.
		## and make sure all the existing tests pass.
		## give the tag options 
		## so that entire part basically.
		## today it should just send an sms and an email with a link to download the pdf. and all the other tests should be passing, so we basically have to rework this code and decomplicate it.
		## put it on the pdf itself ->
		## pdf_to_be_generated
		## put that in the pdf concern.
		
		##########################################################
		##
		##
		## ORDER FINALIZATION.
		##
		##
		##########################################################

		attribute :finalize_order, Integer, mapping: {type: 'integer'}, DEFAULT: NO

		###############################################
		##
		##
		## RECIPIENT
		##
		##
		##############################################

		#attribute :recipients, Array[Notification::Recipient]

		#attribute :additional_recipients, Array[Notification::Recipient]

		## so it has to have recipients
		## 

		## ids of the recipients which we want to disable receiveing the reports.
		attribute :disable_recipient_ids, Array

		## so now move to the actual code of
		## sending the notifications and the background job.
		## 2 tests an hour is also a hell of a lot.
		## ids of the recipients which we want to resend the reports to.
		attribute :resend_recipient_ids, Array

		## skip resend notifications
		attr_accessor :skip_resend_notifications

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
		  		
		    mappings dynamic: 'true' do
			    
		    	indexes :name, type: 'keyword', fields: {
			      	:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
			      	}
			    }

			   	indexes :categories, type: 'nested', properties: Inventory::Category.index_properties
			   	
			   	indexes :reports, type: 'nested', properties: Diagnostics::Report.index_properties
			   	
			   	indexes :receipts, type: 'nested', properties: Business::Receipt.index_properties
			   	
			   	indexes :recipients, type: 'nested', properties: Notification::Recipient.index_properties

			   	indexes :additional_recipients, type: 'nested', properties: Notification::Recipient.index_properties

			   	indexes :visit_type_tags, type: 'nested', properties: Tag.index_properties

			end

		end

		## do this on order.
		## only.
		validate :can_modify, :if => Proc.new{|c| !c.changed_attributes.blank?}

		validate :tests_verified_by_authorized_users_only, :if => Proc.new{|c| !c.changed_attributes.blank?}

		validate :receipts_size_unchanged

		validate :receipts_attributes_unchanged_except_payments

		validate :order_can_be_finalized, :if => Proc.new{|c|
			c.changed_attributes.include? "finalize_order"
		}	

		## once finalized can it be changed again ?

		## if you do it each time, it will be a problem.
		before_save do |document|
			document.receipts.each do |receipt|
				#puts "going to update the total."
				throw(:abort) unless receipt.update_total
			end
		end

		after_save do |document|
			if document.trigger_lis_poll == YES
				document.reports.each do |report|
					$event_notifier.trigger_lis_poll(report.currently_held_by_organization,{:epoch => document.changed_for_lis.to_i.to_s})
				end
			else
				if document.all_reports_verified?
					$event_notifier.trigger_order_delete(report.currently_held_by_organization,{:order_id => self.id.to_s})
				end
			end
		end

		## after find is not being done for the reports.
		## i think.
		## okay so why did it generate the report.
		## now let me add one signature.
		## this should happen before the validations.
		## not after.
		before_validation do |document|
			#################################################
			##
			##
			## IF WE ARE DOING A TOP UP
			## WE NEED THE DUMMY PATIENT -> of the organization
			## of the creating user
			## all that has to be populated herewith.
			## does the payment also have to be created?
			## without a receipt, it cannot be generated.
			## that has to be done after generate receipts
			## then on creating this -> it has to be go to the verification -> online by paypal. 
			##
			##
			#################################################
			document.check_for_top_up
			#################################################
			##
			##
			#################################################
			document.load_patient
			document.update_reports
			document.update_recipients
			document.update_requirements
			document.update_report_items
			document.gather_history
			document.add_report_values
			document.verify
			document.set_accessors
			document.set_changed_for_lis
			document.generate_report_impressions
			document.generate_receipts
			document.cascade_id_generation(nil)
		end


		after_validation do |document|
			document.set_force_pdf_generation_for_receipts
			document.resend_notifications unless document.skip_resend_notifications.blank?
		end


		after_find do |document|
			document.load_patient
			document.set_accessors
		end

	end

	#################################
	def recipients_include_patient?
		unless self.patient.blank?
			self.recipients.select{|c|
				c.patient_id == self.patient.id.to_s
			}.size == 1
		else
			false
		end
	end

	def recipients_include_creating_user?
		self.recipients.select{|c|
			c.user_id == self.created_by_user.id.to_s
		}.size == 1
	end

	def organization_defined_recipients
		recipients_to_add = []

		#puts "organization defined recipients are:"
		
		#puts self.created_by_user.organization.gather_recipients.to_s

		self.created_by_user.organization.gather_recipients.each do |r|
			#puts "the default organization recipieint is:"
			#puts r.to_s
			k = self.recipients.select{|c|
				r.matches?(c)
			}
			#puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			#puts "matching stuff is:"
			#puts k.to_s
			#puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			if k.size == 0
				recipients_to_add << r
			else
				
			end
		end
		recipients_to_add
	end

	## if the size changes ?
	## so we keep two different arrays
	## and do that checking on it.
	## and additional recipients is another array
	## that can be edited only by the user who created the order ? or belonging to the same organization.
	def update_recipients
		#puts "starting now ------------------>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
		unless recipients_include_patient?	
			#puts "recipients dont include the patient, so added it, size now is: #{self.recipients.size}"
			self.recipients <<  Notification::Recipient.new(patient_id: self.patient.id.to_s) 
		end
			
		## this should be integrated into the gather_recipients call.

		k = organization_defined_recipients	
		
		#puts "organization defined recipients are:"
		
		#puts k

		k.each do |r|
			self.recipients << r
		end

		#puts "size at close is: "
		#puts self.recipients.size
		#puts "-----------------------------------------------------------------------(((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((("

	end

	## so the next step is that we test this and add removal of different recipients.
	## and who can add or remove these recipients ?
	## the order creator only can do that.
	## so accessibility control.
	## if the recipients have changed, it should be by the 
	## so if the size changes, it can be because a recipient was added internally
	## so a new recipient was added.
	## 

	## @called_from : before_validation.
	def check_for_top_up
		if self.do_top_up == YES
			if top_up_report = Diagnostics::Report.get_top_up_report
				self.template_report_ids << top_up_report.id.to_s
			else
				self.errors.add(:do_top_up,"The Top Up Option is missing, please contact the developers")
			end
		end
	end

	# @Called_from : before_validation in self.
	# @used_to : set an attribute on self called set_changed_for_lis, this is used by the local lis to check for which orders have changed and download them.
	def set_changed_for_lis
		## so in this case, we reset and then set only
		## so after save it is accessible.
		self.trigger_lis_poll = NO
		return if self.new_record?
		if self.validations_to_skip.blank?
		else
			return if self.validations_to_skip.include? "set_changed_for_lis"
		end
		
		#puts "inside changed for lis---"
		#puts "the changed attributes"
		#puts self.changed_attributes.to_s

		#puts "changed array attribute sizes:"
		#puts self.changed_array_attribute_sizes.to_s

		## okay so good old changed attributes.
		## so changed for lis is not suppose to be triggered here.
		## what about if this is a new record ?
		## 
		## if the changed for lis itself was changed, don't do anything
		return if self.changed_attributes.include? "changed_for_lis"

		["template_report_ids","categories"].each do |k|
			if self.changed_array_attribute_sizes.include? k
				self.changed_for_lis = Time.now.to_i
				## here we push the event notification
				self.trigger_lis_poll = YES
			end
		end
		## only if all requirements fulfilled.
		## otherwise none of this is of any use.
		## so will have to set this.
		self.categories.each do |category|

			#puts "is the category newly added?"
			#puts category.newly_added
			#puts "category changed attributes ---------->"
			#puts category.changed_attributes.to_s
			#puts category.changed_array_attribute_sizes.to_s
			#puts category.changed_array_attribute_sizes
			unless category.changed_array_attribute_sizes.blank?
				if category.changed_array_attribute_sizes.include? "items"
					self.changed_for_lis = Time.now.to_i
					self.trigger_lis_poll = YES
				else
					category.items.each do |item|

						if item.changed_attributes.include? "use_code".to_sym
							self.changed_for_lis = Time.now.to_i
							self.trigger_lis_poll = YES
							## this has to trigger after save.
							## not before.
						end
					end
				end
			end
			
		end

	end


	def tests_verified_by_authorized_users_only
		
		#exit(1)
		self.changed_attributes.each do |attr|

			if attr.to_s == "reports"
				#puts "changed ers Docuattribute is: reports"
				self.reports.each do |r|
					#puts "repoort changed parameters are:"
					#puts r.changed_attributes.to_s
					next if r.changed_attributes.blank?
					if r.changed_attributes.include? "tests"
						#puts "changed attribute is :tests"
						r.tests.each do |test|
							#puts "test changed parameters are:"
							#puts test.changed_attributes.to_s
							next if test.changed_attributes.blank?
							#puts "the test changed attributes are: #{test.changed_attributes}"
							if test.changed_attributes.include? "verification_done"
								 
								#puts "verification done has changed."
								
								if r.organization.user_can_verify_test?(self.created_by_user,test)

									#puts "user is allowed to verify the test"

									if test.verification_done == Diagnostics::Test::VERIFIED
										test.verification_done_by << self.created_by_user.id.to_s
									end

								else
									test.errors.add(:verification_done,"You do not have sufficient permissions to verify this test")
								end
							end
						end
					end
				end
			end
		end
		#exit(1)
	end	

	## validation, called if finalize_order has changed.
	## how does the range interpretation take place with these tags.
	## ya i can deliver it on the pathofast portal
	def order_can_be_finalized
		self.reports.each do |report|

			#puts "checking report: #{report.id.to_s}"
				
			report.requirements.each do |req|
				#puts "checking requirement: #{req.id.to_s}, is it satisfied: #{req.satisfied?}"					
				self.errors.add(:requirements, "the requirement: #{req.name} was not satisfied") unless req.satisfied?
			end

			report.tests.each do |test|
				#puts "checking test: #{test.name.to_s}"
				self.errors.add(:reports, "the test #{test.name}, in the report: #{report.name}, has not been provided with the relevant history #{test.get_history_questions}, please answer questions to finalize the order") unless test.history_provided?(self.history_tags)
			end
		end
	end

	def receipts_size_unchanged
		#unless ((self.prev_size["receipts"].blank?) && (self.current_size["receipts"].blank?))
			#if self.prev_size["receipts"] != self.current_size["receipts"]
				self.errors.add(:receipts, "you cannot add or remove receipts") if self.changed_array_attribute_sizes.include? "receipts"
			#end
		#end
	end

	## 
	def receipts_attributes_unchanged_except_payments
		self.receipts.each do |receipt|
			self.errors.add(:receipts, "you cannot change receipt attributes") if receipt.parameter_other_than_payments_changed?
		end
	end

	## so we have an array called resend_to_recipient_ids.

	## @called from : self, it is a validation.
	def can_modify
		self.changed_attributes.each do |attr|

			if attr.to_s == "reports"
				self.reports.each do |r|
					unless r.changed_attributes.blank?
						if r.owner_ids.include? self.created_by_user_id
						elsif r.owner_ids.include? self.created_by_user.organization.id.to_s
						else
							self.errors.add(:reports,"You cannot edit #{attr.name.to_s}")
						end
					end
				end
			
			elsif attr.to_s == "recipients"
				recipients_changed
			elsif attr.to_s == "payments"
				old_payment_not_deleted
			else
				## only in case of 
				if self.owner_ids.include? self.created_by_user.id.to_s
				elsif self.owner_ids.include? self.created_by_user.organization.id.to_s
				else
					self.errors.add(:owner_ids,"You cannot edit the field: #{attr.to_s}")
				end
			end

		end
	end

	# i can segregate the code bits.
	# but later
	# today i want this out of the way.

	########################################################
	##
	##
	## NOTIFICATION METHODS : OVERRIDDEN FROM THE 
	##
	##
	########################################################
	def before_send_notifications
		return true unless self.resend_recipient_ids.blank?
		return true unless self.force_send_notifications.blank?
		return false
	end

	## sends notification, sms, and email to all the recipients, of the order
	## now we test -> force, resend, receipt notifications
	## and what happens in stuff like things being added/removed etc.
	## okay get it working for receipt.
	## here send notifications is triggered after_pdf_generation.
	## it should be same in the receipt.
	def send_notifications
		phones_sent_to = []
		emails_sent_to = []
		gather_recipients.each do |recipient|
			recipient.phone_numbers.each do |phone_number|
				next if phones_sent_to.include? phone_number
				phones_sent_to << phone_number
				response = Auth::TwoFactorOtp.send_transactional_sms_new({
					:to_number => phone_number,
					:template_name => REPORT_UPDATED_TEMPLATE_NAME,
					:var_hash => {:VAR1 => self.patient.first_name, :VAR2 => self.patient.last_name, :VAR3 => self.pdf_url, :VAR4 => self.created_by_user.organization.name },
					:template_sender_id => REPORT_UPDATED_SENDER_ID
				})
			end
			unless recipient.email_ids.blank?
				email = OrderMailer.report(recipient,self,self.created_by_user,(recipient.email_ids - emails_sent_to))
	        	email.deliver_now
	        	emails_sent_to << recipient.email_ids
	        	emails_sent_to.flatten!
        	end
    	end
	end
	##############################################################
	##
	##
	## PAYMENTS VALIDATION CHECKING
	##
	## ALL THE FOLLOWING ARE HELPER METHODS CALLED FROM WITHIN the self#can_modify validation, if the changed attribute is a payment.
	## 
	##
	##############################################################
	def old_payment_not_deleted
		self.errors.add(:payments,"a payment has been deleted, this operation is not allowed") if self.current_size("payments") < self.prev_size("payments")
	end


	def recipients_changed
		self.errors.add(:recipients, "you cannot change the default recipients of this orders reports")
	end



	## sets the accessors of order, if any, and also those of the
	## child elements.
	def set_accessors
		## and the location.
		self.reports.each do |report|
			report.order_organization = self.organization
			report.set_accessors
		end
	end


	def sample_will_be_delivered_to_lab?
		return false if self.visit_type_tags.blank?
		return self.visit_type_tags[0].name == Tag::SAMPLE_WILL_BE_DELIVERED_TO_LAB
	end

	def is_phlebotomist_visit?
		return false if self.visit_type_tags.blank?
		return self.visit_type_tags[0].name == Tag::PHLEBOTOMIST_VISIT
	end


	def is_courier_visit?
		return false if self.visit_type_tags.blank?
		return self.visit_type_tags[0].name == Tag::COURIER_VISIT
	end


	def is_lab_visit?
		return false if self.visit_type_tags.blank?
		return self.visit_type_tags[0].name == Tag::PATIENT_VISIT_LAB
	end

	def set_visit_location_options
		## if the vist_type_tags have changed
		if self.changed_attributes.include? "visit_type_tags"
			if is_phlebotomist_visit?
				## we have to show location options
				## the patient's location
				## the organizations location
				## ask them to enter a location -> that can always been defined.
				## and this is only if order is not finalized.
				## suppose you want to change after the order is finalized.
				## you can cancel it and start over
			elsif is_courier_visit?
			
			elsif is_lab_visit?
			
			elsif sample_will_be_delivered_to_lab?
			
			else
			
			end
		end
	end

	## @param[Diagnostics::Report] report : 
	## @Called_from : self#remove_reports
	## called if a report is marked for removal, so that any additional hooks like removal of requirements, etc can be fired.
	def on_remove_report(report)
		self.receipts.each do |receipt|
			receipt.cancel_payments({report: report})
		end
	end

	## @called_from : self#update_reports.
	def remove_reports
		#puts "came to delete reports."
		#puts "Reports size before:"
		#puts self.reports.size.to_s
		self.reports.delete_if { |c|
			unless self.template_report_ids.include? c.id.to_s
				if c.can_be_removed?
					on_remove_report(c)
					true
				else
					self.errors.add(:reports,"the report: #{c.name} cannot be removed")
					false
				end
			end
		}
		#puts "reports size after"
		#puts reports.size.to_s
	end

	## i can go for accounting.
	## generate that pdf, and see how to make the online payment.
	## finalize that flow.
	## secondly also finalize the accounting.
	## allowing an organization to get detailed insights into 
	## its outsourcing patterns.

	def update_reports

		remove_reports

		existing_report_ids = self.reports.map{|c|
			c.id.to_s
		}

		self.template_report_ids.each do |r_id|
			#puts "doing template report id: #{r_id}"
			unless existing_report_ids.include? r_id
				puts "rid is: #{r_id}"
				report = Diagnostics::Report.find(r_id)
				#puts "report is :#{report}"
				puts "created by user id is: #{report.created_by_user_id}"
				report.created_by_user = User.find(report.created_by_user_id)
				report.current_user = self.current_user
				#puts "report found is: #{report.id.to_s}"
				#exit(1)
				report.run_callbacks(:find)
				#before adding the report, prune that bitch.
				#for all the ranges.
				report.prune_test_ranges(self.patient)
				self.reports << report
			end
		end
	end

	## so from where are we going to be able to add the 
	## created_by_user_id for the payment ?
	## it will have to be passed in ?
	## or what ?
	## 

	## that's because before save happens after validate.
	## and so its not triggering the first time.
	## but is triggering thereafter.
	## give it a default value in the form itself.
	## why is this schedule shit not working.

	def load_patient
		#puts "CAME TO LOAD THE PATIENT"
		if self.patient_id.blank?
			self.errors.add(:patient_id,"Please choose a patient for this order.")
		else
			self.patient = Patient.find(self.patient_id)
			self.patient.run_callbacks(:find)
		end
	end

	def get_schedule
  		search_request = Schedule::Minute.search({
  			size: 0,
  			query: {
  				bool: {
  					must: [
  						{
  							nested: {
  								path: "employees",
  								query: {
  									nested: {
  										path: "employees.bookings",
  										query: {
  											term: {
  												"employees.bookings.order_id".to_sym => self.id.to_s
  											}
  										}
  									}
  								}
  							}
  						}
  					]
  				}
  			},
  			aggs: {
  				minute: {
  					terms: {
  						field: "number",
  						order: {
  							"_key".to_sym => "asc"
  						}
  					},
  					aggs: {
  						employees: {
  							nested: {
  								path: "employees"
  							},
  							aggs: {
  							 	employees: {
  							 		filter: {
  							 			nested: {
  							 				path: "employees.bookings",
  							 				query: {
  							 					term: {
  							 						"employees.bookings.order_id".to_sym => self.id.to_s
  							 					}
  							 				}
  							 			}
  							 		},
  							 		aggs: {
  							 			employees: {
  							 				terms: {
  							 					field: "employees.employee_id"
  							 				},
  							 				aggs: {
  							 					bookings: {
  							 						nested: {
  							 							path: "employees.bookings"
  							 						},
  							 						aggs: {
  							 							bookings_filtered: {
  							 								filter: {
  							 									term: {
  							 										"employees.bookings.order_id".to_sym => self.id.to_s
  							 									}
  							 								},
  							 								aggs: {
  							 									status_ids: {
		  							 								terms: {
		  							 									field: "employees.bookings.status_id"
		  							 								},
		  							 								aggs: {
		  							 									report_ids: {
		  							 										terms: {
		  							 											field: "employees.bookings.report_ids"
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
  		})
  		search_request.response.aggregations
  	end

	def assign_id_from_name
		self.name = BSON::ObjectId.new.to_s
		self.id = self.name
	end

	## first reset all the required quantitis.
	def reset_category_quantities_and_reports
		self.categories.map {|cat|
			cat.quantity = 0	
			cat.required_for_reports = []
			cat.optional_for_reports = []
		}
	end

	def has_category?(name)
		self.categories.select{|c|
			c.name == name
		}.size > 0
	end


	## will build the categories array using the requirements defined in the reports.
	## before starting will clear all the quantites from existing elements of hte categories array.
	## and then will add a category if it doesn't exist, and if it exists, will increment its quantity.
	def update_requirements
		reset_category_quantities_and_reports
		self.reports.map{|report|
			report.requirements.each do |req|
				options = req.categories.size
				req.categories.each do |category|
					#puts "looking for category: #{category.name}"
					if !has_category?(category.name)
						category_to_add = Inventory::Category.new(quantity: category.quantity, required_for_reports: [], optional_for_reports: [], name: category.name)
						if options > 1
							category_to_add.optional_for_reports << report.id.to_s
						else
							category_to_add.required_for_reports << report.id.to_s
						end
						self.categories << category_to_add
					else
						self.categories.each do |existing_category|
							if existing_category.name == category.name
									
								existing_category.quantity += category.quantity

								if options > 1
									existing_category.optional_for_reports << report.id.to_s
								else
									existing_category.required_for_reports << report.id.to_s
								end

								existing_category.optional_for_reports.flatten!

								existing_category.required_for_reports.flatten!

							end
						end
					end
				end
			end
		}		
	end

	## whatever items the user has added to the categories will be updated to the reports.
	def update_report_items
		self.reports.map{|c|
			c.clear_all_items
		}

		self.categories.each do |category|
			puts "doing category: #{category.name}"

			category.set_item_report_applicability(self.reports)
			
			category.items.each do |item|
				puts "item applicable to reports are:"
				puts item.applicable_to_report_ids.to_s
				#exit(1)
				## can this item be created at all?
				## that's the first thing.f
				self.reports.each do |report|
					## if the report id is there in the item applicability then only add it.
					## and add the errors to the other items.
					## these will be displayed.
					## now add errors on the other items.
					if item.applicable_to_report_ids.include? report.id.to_s
						report.add_item(category,item)
					end
				end
			end
		end
	end

	## @return[Hash[Tag]] hash of history tags, keyed by the id of the tag
	## whose questions were answered
	## @called_From : self#before_validation
	def gather_history
		self.history_tags = {}
		self.reports.each do |report|
			report.tests.each do |test|
				test.tags.each do |tag|
					if tag.is_history_tag?
						self.history_tags[tag.id.to_s] = tag if tag.history_answered?
					end
				end
			end
		end
	end

	## next step is to display the created report
	## for now just let me make something simple.
	## called before save, to add the patient values
	def add_report_values
		## so this can only happen if the order is finalized.
		## that is the main thing.

		unless self.patient.blank?
			self.reports.map{|report|
				report.tests.map{|test|
					test.add_result(self.patient,self.history_tags) 
				}
			}
		end
	end


	def verify
		self.reports.each do |report|
			if report.verify_all == Diagnostics::Report::VERIFY_ALL
				report.tests.each do |test|
					test.verify_if_normal
				end
			end
		end
	end

	def group_reports_by_organization
		self.reports_by_organization = {}
		self.users_hash = {}
	
		self.reports.each do |report|
			
			user_ids = []

			if self.reports_by_organization[report.organization.id.to_s].blank?
				self.reports_by_organization[report.organization.id.to_s] = [report.id.to_s]
				user_ids << report.gather_signatories			
			else
				self.reports_by_organization[report.organization.id.to_s].blank?
				self.reports_by_organization[report.organization.id.to_s] << report.id.to_s
				user_ids << report.gather_signatories				
			end

			
			#puts "the user ids are:"
			#puts user_ids.to_s

			user_ids.flatten.map{|c| self.users_hash[c] = User.find(c) if self.users_hash[c].blank? }

			#puts "users hash contains"
			#puts self.users_hash

			## 

			if report.is_outsourced?

				#puts "the report is outsourced"
				#puts "report final signatories are:"
				#puts report.final_signatories.to_s
				# i think it has gone to outsourced report
				# i think there additional employee something has bombed.
				# gotta check this.

				if self.organization.outsourced_reports_have_original_format == Organization::YES

					#puts "the organization says outsourced reports should have the original format."
					
					report.final_signatories.reject! { |c|  !report.can_sign?(users_hash[c])}

					report.final_signatories += self.organization.additional_employee_signatures
					
				else

					#puts "the organization says outsourced reports should not have the original format, so the which of our employees will resign, is being triggered."

					self.organization.which_of_our_employees_will_resign_outsourced_reports.each do |u_id|
						## add to users hash.
						self.users_hash[u_id] = User.find(u_id) if self.users_hash[u_id].blank?
					end 

					report.final_signatories = self.organization.which_of_our_employees_will_resign_outsourced_reports

					report.final_signatories.reject! { |c|  !report.can_sign?(users_hash[c])}

					## problem is that if these are not and will not be present.

					report.final_signatories += report.organization.additional_employee_signatures

				end

			else

				report.final_signatories.reject! { |c|  !report.can_sign?(users_hash[c])}

				report.final_signatories += self.organization.additional_employee_signatures

			end

		end
		
	end

	## this is happening at that level.

	## how to synchronize the queries.
	## group statuses by query ?
	## maybe that will work, if the start time and end time is the same ?
	## so i need to merge statuses
	## somehow.
	## if its start and end time is exactly the same
	## it can be merged for the query.
	def has_abnormal_reports?
		self.reports.select{|c|
			c.has_abnormal_tests?
		}.size > 0
	end


	########################################################
	##
	##
	## RCEIPTS
	##
	##
	########################################################

	def bill_direct_to_patient?
		if self.bill_outsourced_reports_to_patient == YES
			true
		else
			self.organization.bill_outsourced_reports_to_patient == YES
		end
	end


	## @param[String] payable_to_organization_id[REQUIRED] : The id of the organization to which the bill is to be paid.
	## @param[String] payable_from_organization_id[OPTIONAL] : The id fo the organization from which the bill is to be paid.
	## @param[String] payable_from_patient_id[OPTIONAL] : the id of the patient from which the bill is to be paid.
	## @return[Business::Receipt] receipt : the first receipt which satisfies organization-organization or organization-patient, or nil.
	def existing_receipt?(payable_to_organization_id,payable_from_organization_id,payable_from_patient_id)

		payable_to_this_org = self.receipts.select{|c|
			(c.payable_to_organization_id == payable_to_organization_id)
		}

		return false if payable_to_this_org.blank?

		k = nil
		if !payable_from_organization_id.blank?
			k = payable_to_this_org.select{|c|
				c.payable_from_organization_id == payable_from_organization_id
			}
		elsif !payable_from_patient_id.blank?
			k = payable_to_this_org.select{|c|
				c.payable_from_patient_id == payable_from_patient_id
			}
		end

		if k.blank?
			nil
		else
			k[0]
		end

	end


	def find_or_initialize_receipt(payable_to_organization_id,payable_from_organization_id,payable_from_patient_id)

		
		if r = existing_receipt?(payable_to_organization_id,payable_from_organization_id,payable_from_patient_id)
			#puts "there is an existing receipt."
			r
		else
			r = Business::Receipt.new(payable_to_organization_id: payable_to_organization_id, payable_from_organization_id: payable_from_organization_id, payable_from_patient_id: payable_from_patient_id, force_pdf_generation: true, current_user: self.current_user, newly_added: true)
			r.update_recipients
			#exit(1)
			self.receipts << r
			r
		end

		## so basically here, and also on adding any payment.
		## and also if a payment has been added from outside.

	end

	## we may have to add this receipt if 
	## @param[String] from_organization_id : organization from which to bill the patient.
	## @param[Diagnostics::Report] report : the report for which this bill is being added.
	## @called_from : self#generate_receipts
	def receipt_to_patient(from_organization_id,report) 
		r = find_or_initialize_receipt(from_organization_id,nil,self.patient.id.to_s)
		r.add_bill(Business::Payment.bill_patient_for_report(from_organization_id,self.patient,report))
	end

	## @param[Diagnostics::Report] report : the report for which this bill is being added.
	## @called_from : self#generate_receipts
	def receipt_to_order_organization(report)
		## cascading of after find callback is not working.
		r = find_or_initialize_receipt(report.currently_held_by_organization,self.organization.id.to_s,nil)
		r.add_bill(Business::Payment.bill_from_outsourced_organization_to_order_organization(report,self))
	end

	def generate_receipts
		## so clear every receipt of reports that no longer exist. 
		self.reports.each do |report|
			if report.is_outsourced?
				#puts "report is outsourced."
				if bill_direct_to_patient?
					#this will be true.
					#puts "we are on bill direct to patient."
					#will be receipt to patient via organizaiton.
					receipt_to_patient(report.currently_held_by_organization,report)
					#(from_organization_id,report) 
				else
					#puts "we are on double bill"
					receipt_to_patient(self.organization.id.to_s,report)
					receipt_to_order_organization(report)
				end
			else
				#puts "Receipt to patient ----------------------"
				receipt_to_patient(self.organization.id.to_s,report)
			end
		end
	end

	########################################################
	##
	##
	## REPORT IMPRESSIONS
	##
	##
	########################################################
	## if a report has a verification done.
	## unless all reports 

	## @called_from : SELF#before_validation
	def generate_report_impressions
		self.reports.each do |report|
			if report.impression.blank?
				report.impression = ""
				report.tests.each do |test|
					report.impression += (" " + (test.display_comments_or_inference || ""))
				end
			end
		end
	end


	
	#############################################################
	##
	##
	## PDF GENERATION
	##
	##
	#############################################################
	def any_report_just_verified?
		self.reports.select{|c|
			c.a_test_was_verified? && c.is_verified?
		}.size > 0
	end

	def all_reports_verified?
		self.reports.select{|c|
			c.is_verified?
		}.size == self.reports.size
	end

	def proceed_for_pdf_generation?
		((any_report_just_verified? && (self.organization.generate_partial_order_reports == YES)) || (all_reports_verified? && any_report_just_verified?) || (!self.force_pdf_generation.blank?))
	end
	
	def before_generate_pdf
		return false unless self.skip_pdf_generation.blank?
		return proceed_for_pdf_generation?
	end

	## so let's check the mailer if its sending this or not.

	def after_generate_pdf
		send_notifications
	end

	def generate_pdf

		
		return if self.reports.blank?

		self.group_reports_by_organization

		if self.organization.outsourced_reports_have_original_format == Organization::YES

			self.reports_by_organization.keys.each do |organization_id|
				build_pdf(self.reports_by_organization[organization_id],organization_id,get_signing_organization(self.reports_by_organization[organization_id]))
			end
		else

			build_pdf(self.reports.map{|c| c.id.to_s},self.organization.id.to_s,get_signing_organization(self.reports))

		end
		
		after_generate_pdf

	end
	
	def set_force_pdf_generation_for_receipts
		if self.new_record?
			self.receipts.each do |r|
				r.force_pdf_generation = true
			end
		end
	end

	## @Called_from : self#generate_pdf
	def get_signing_organization(reports)

		first_report = reports.first

		results = {
			:signing_organization => nil
		}

		## make some dummy users
		## give them each credentials.
		## make three reports by one organization
		## and one report by the other organization
		## then 

		if first_report.report_is_outsourced

			if first_report.order_organization.outsourced_reports_have_original_format == Organization::NO
						
					results[:signing_organization] = first_report.organization
			else
					results[:signing_organization] = first_report.order_organization
			end

		else

			results[:signing_organization] = first_report.order_organization

		end

		return results[:signing_organization]

	end

	

	

	## @param[Array] report_ids : the array of report ids.
	## @param[String] organization_id : the id of the organization on whose letter head the reports have to be generated.
	## @param[Organization] signing_organzation : the organization whose representatives will sign on the report.
	## so its making the pdf.
	## now the next step is to move to what ?
	def build_pdf(report_ids,organization_id,signing_organization)
		
		time_stamp = Time.now.to_i.to_s

		file_name = time_stamp + "_" + self.id.to_s + "_" + self.patient.full_name
	   
	    ac = ActionController::Base.new

	    pdf = ac.render_to_string pdf: file_name,
            template: "#{ Auth::OmniAuth::Path.pathify(self.class.name).pluralize}/pdf/show.pdf.erb",
            locals: {:order => self, :reports => self.reports.select{|c| report_ids.include? c.id.to_s}, :organization => Organization.find(organization_id), :signing_organization => signing_organization},
            layout: "pdf/application.html.erb",
            quiet: true,
            header: {
            	html: {
            		template:'/layouts/pdf/header.pdf.erb',
            		layout: "pdf/application.html.erb",
            		locals:  {:order => self, :reports => self.reports.select{|c| report_ids.include? c.id.to_s}, :organization => Organization.find(organization_id), :signing_organization => signing_organization}
            	}
            },
            footer: {
           		html: {   
           			template:'/layouts/pdf/footer.pdf.erb',
           			layout: "pdf/application.html.erb",
            		locals: {:order => self, :reports => self.reports.select{|c| report_ids.include? c.id.to_s}, :organization => Organization.find(organization_id), :signing_organization => signing_organization}
                }
            }       

        save_path = Rails.root.join('public',"#{file_name}.pdf")
		File.open(save_path, 'wb') do |file|
		  file << pdf
		  self.pdf_urls = [save_path]
		  self.pdf_url = save_path
		end
		#puts "the pdf url is==========>"
		#puts self.pdf_url
		#exit(1)

		## and send the transactional sms.

=begin
	    Tempfile.open(file_name) do |f| 
		  f.binmode
		  f.write pdf
		  f.close 
		  #IO.write("#{Rails.root.join("public","test.pdf")}",pdf)
		  response = Cloudinary::Uploader.upload(File.open(f.path), :public_id => file_name, :upload_preset => "report_pdf_files")
		  puts "response is: #{response}"
		  self.latest_version = response['version'].to_s
		  self.pdf_url = response["url"]
		end
=end

		self.skip_pdf_generation = true
		
		#self.save		

	end

	## the order referred to here is the order that came in from the lis.
	## @called_From : self#update_lis_result
	## the results are keyed by organization id.
	## this prevents us from inadvertently updating a matching lis code of a report outsourced to another organization.
	## @return[Hash] : {lis_code => {report_organization_id => result_raw}}
	def get_test_to_result_hash
		lis_code_to_results_hash = {}
		self.reports.map{|c|
			## so it doesn't have the currently_held_by_organization.
			report_organization_id = c.currently_held_by_organization
			c.tests.map{|t|
				if lis_code_to_results_hash[t.lis_code].blank?
					lis_code_to_results_hash[t.lis_code] = {}
				end
				lis_code_to_results_hash[t.lis_code][report_organization_id] = t.result_raw		
			}
		}
		lis_code_to_results_hash
	end

	###############################################################
	##
	##
	## METHODS.
	##
	##
	###############################################################
	## @param[Business::Order] order_from_lis : incoming order from,
	## @called_from : interfaces_controller.rb#update
	## @return[nil]
	def update_lis_results(order_from_lis)
		self.tests_changed_by_lis ||= {}
		test_to_result_hash = order_from_lis.get_test_to_result_hash
		puts "test to result hash is:"
		puts test_to_result_hash
		## suppose an order no longer exists.
		## test has changed / been deleted
		## anything.
		## but the update is complete
		## if the request returns
		## if that order is not found, then what do we do.
		## 
		self.reports.each do |report|
			report.tests.each do |test|
				unless test_to_result_hash[test.lis_code].blank?
					if test.can_be_updated_by_lis?(test_to_result_hash[test.lis_code],report)
						puts "came to yes we can update ht result."
						puts test_to_result_hash[test.lis_code]
						puts "the raw result is:"
						puts test_to_result_hash[test.lis_code][report.currently_held_by_organization]

						test.result_raw = test_to_result_hash[test.lis_code][report.currently_held_by_organization]
						puts "result raw is: #{test.result_raw}"
						if self.tests_changed_by_lis[test.lis_code].blank?
							self.tests_changed_by_lis[test.lis_code] = {report.currently_held_by_organization => []}
						end
						self.tests_changed_by_lis[test.lis_code][report.currently_held_by_organization] << test_to_result_hash[test.lis_code]
					end
				else
					puts "test to result has is blank for: #{test.lis_code}"
				end
			end
		end
	end

	## called from #interfaces_controller.rb#update_many
	## used to check if the expected updates were executed on this order or not.
	## @param[Hash] expected_updates : {lis_code => {organization_id => raw_result}}
	## @return[nil], will add an error to the order, if any of the expected updates are not found on it.
	def lis_updates_done?(expected_updates)
		self.reports.each do |report|
			report.tests.each do |test|
				report_org = report.currently_held_by_organization
				if !expected_updates[test.lis_code].blank?
					if !expected_updates[test.lis_code][currently_held_by_organization].blank?
						self.errors.add(:tests, "the test: #{test.name}, was not successfully updated") unless (test.result_raw == expected_updates[test.lis_code][currently_held_by_organization])
					end
				end
			end
		end
	end

	## so if have a disable -> it will check that before sending
	## if resend is set -> then that is an accessor.
	## and if populated then will resend and clear.
	## is that done before save or after save ?
	## before_save
	module ClassMethods

		def permitted_params
			base = [
					:id,
					{:order => 
						[
							:id,
							:name,
							{:disable_recipient_ids => []},
							{:resend_recipient_ids => []},
							{:template_report_ids => []},
							:patient_id,
							:local_item_group_id,
							:start_epoch,
							{
								:categories => Inventory::Category.permitted_params
							},
					    	{
					    		:receipts => Business::Receipt.permitted_params
					    	},
					    	{
					    		:reports => Diagnostics::Report.permitted_params[1][:report]
					    	},
					    	{
					    		:recipients => Notification::Recipient.permitted_params
					    	},
					    	{
					    		:additional_recipients => Notification::Recipient.permitted_params
					    	},
					    	{
					    		:visit_type_tags => Tag.permitted_params
 					    	},
					    	:procedure_versions_hash,
					    	:created_at,
					    	:updated_at,
					    	:public,
					    	:currently_held_by_organization,
					    	:created_by_user_id,
					    	:owner_ids,
					    	:bill_outsourced_reports_to_patient,
					    	:bill_outsourced_reports_to_order_creator,
					    	:do_top_up,
					    	:finalize_order
						]
					}
				]
			if defined? @permitted_params
				base[1][:order] << @permitted_params
				base[1][:order].flatten!
			end
			base
		end
		##########################################################
		##
		##
		##
		###########################################################
		## @Called_from : interfaces_controller.rb
		## @Return[Hash key: (string) => value : (Business::Orders)]
		## @param[Hash] : args => can consist of the following keys
		## :items => array of Inventory::Item objects
		## :orders => array of Business::Order obbjects  
		def find_orders(args)
			#puts "came to find orders -=------------->"
			#puts args.to_s
			#exit(1)
			if !args[:items].blank?
				## adds bulk search items.
				## { index: 'myindex', type: 'mytype', search: { query: { query_string: { query: '"Test 1"' } } } }
				items.each do |item|
					add_bulk_item({
						index: Business::Order.index_name,
						search: {
							query: {
								bool: {
									should: [
										{
											term: {
												barcode: item.code
											}
										},
										{
											term: {
												code: item.code
											}
										}
									]
								}
							}
						}
					})
				end
			elsif !args[:orders].blank?
				#puts "orders are:"
				#puts args[:orders].size
				add_bulk_item({
					index: Business::Order.index_name,
					search: {
						sort: {
							"_id".to_sym => {
								order: "desc"
							}
						},
						query: {
							ids: 
								{
									values: args[:orders].map{|c| c.id.to_s}
								}
						}
					}
				})
			end
			flush_bulk	
			orders = {}
			#puts self.search_results.to_s
			## so we make it a hashie mash.
			self.search_results.each do |response|
				response["hits"]["hits"].each do |hit|
					order = Business::Order.new(hit["_source"])
					order.id = hit["_id"]
					order.created_by_user = User.find(order.created_by_user_id)
					order.run_callbacks(:find)
					orders[order.id.to_s] = order
				end
			end
			orders
		end

		## @param[Hash] params: the params that come into the index action of the interfaces_controller.rb
		## @param[Organization] organization : the organization which was determined in the interfaces controller, based on the lis_security key.
		## it will look for orders which are either owned by the current organization or which have reports, that are being outsourced to this organization.
		## while returning the orders have to be filtered, to contain only those reports.
		## @return[Array] orders : the orders that have got the changed_for_lis between the params[:from_epoch] and params[:to_epoch].
		## @called_from: interfaces_Controller.rb
		def find_orders_changed_for_lis(params,organization)
			total_hits = 0
			search_request = Business::Order.search({
				size: 10,
				from: (params[:skip] || 0),
				query: {
					bool: {
						must: [
							{
								bool: {
									should: [
										{
											term: {
												owner_ids: organization.id.to_s
											}
										},
										{
											nested: {
												path: "reports",
												query: {
													term: {
														"reports.currently_held_by_organization".to_sym => organization.id.to_s
													}
												}
											}	
										}
									]
								}
							}
						],
						should: [
							{
								range: {
									changed_for_lis: {
										gte: params[:from_epoch],
										lte: params[:to_epoch]
									}
								}
							}
						]
					}
				}
			})
			orders = []
			puts search_request.response.to_s
			total_hits = search_request.response.hits.total
			search_request.response.hits.hits.each do |hit|
				order = Business::Order.new(hit["_source"])
				order.id = hit["_id"]
				if order.currently_held_by_organization == organization.id.to_s
					## all reports are permitted.
				else
					## any report which is not being outsourced to the current organization, is removed.
					## as these reports are not having anything to do with the current organization.
					## there can be an lis code clash.
					## cross update should not happen.
					order.reports.reject!{|c|
						c.currently_held_by_organization != organization.id.to_s
					} 
				end
				orders << order
			end
			{orders: orders, size: total_hits}
		end

		def find_incomplete_order_with_barcode(item_id)
			search_request = Business::Order.search({
				size: 1,
				query: {
					bool: {
						must: 
						[
							{
								nested: {
									path: "categories",
									query: {
										nested: {
											path: "categories.items",
											query: {
												bool: {
													should: [
														{
															term: {
																field: ""
															}
														}
													]
												}
											}
										}
									}
								}
							}
						]
					}
				}
			})
		end

	end

end