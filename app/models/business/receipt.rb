require 'elasticsearch/persistence/model'

class Business::Receipt

	include Elasticsearch::Persistence::Model
	include ActiveModel::Serialization
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
  	include Concerns::OwnersConcern
	include Concerns::AllFieldsConcern
	include Concerns::NameIdConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::VersionedConcern
	include Concerns::FormConcern
	include Concerns::PdfConcern
	include Concerns::NotificationConcern
	include Concerns::CallbacksConcern
	include Concerns::BackgroundJobConcern


	## FOR TWO FACTOR OTP SMS.
	RECEIPT_UPDATED_TEMPLATE_NAME = "Receipt Updated"
	RECEIPT_UPDATED_SENDER_ID = "LABTST"

	attribute :name, String, mapping: {type: 'keyword'}, default: BSON::ObjectId.new.to_s

	attribute :payable_to_organization_id, String, mapping: {type: 'keyword'}	
	
	attribute :payable_from_organization_id, String, mapping: {type: 'keyword'}

	attribute :payable_from_patient_id, String, mapping: {type: 'keyword'}

	attribute :payments, Array[Business::Payment]

	attribute :total, Float, mapping: {type: 'float'}, default: 0
		
	attribute :paid, Float, mapping: {type: 'float'}, default: 0

	attribute :pending, Float, mapping: {type: 'float'}, default: 0
		
	LOCKED = "locked"

	UNLOCKED = "unlocked"

	######################################################
	##
	##
	## ATTRIBUTES USED IN THE PDF'S 
	## basically we load the organizations that are 
	## referenced in the receipts.
	##
	##
	##
	######################################################
	attr_accessor :payable_from_organization
	attr_accessor :payable_from_patient
	attr_accessor :payable_to_organization

	## so the payable from/payable from organization.
	## each should get it. 
	## unless it is the same.
	## those are the recipients.
	#####################################################
	##
	## for standalone existing of receipt objects.
	## 
	##
	##
	#####################################################
	### we should be able to take any kind of doctor's report also.

	index_name "pathofast-business-receipts"
	document_type "business/receipt"

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
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    },
	   	 	copy_to: "search_all"
		    indexes :payable_to_organization_id, type: 'keyword'
		    indexes :payable_from_organization_id, type: 'keyword'
		    indexes :payable_from_patient_id, type: 'keyword'
		    indexes :payments, type: 'nested', properties: Business::Payment.index_properties
		    indexes :total, type: 'float'
		    indexes :paid, type: 'float'
		    indexes :pending, type: 'float'
		end
	end

	#####################################################
	##
	##
	## NOTIFICATION CONCERN METHODS
	##
	##
	#####################################################
	## will have to see if all this works.
	## so more integration testing is necessary here.	
	## but generate pdf, is done after_validation
	## so this will work.
	## these before_validations are being called after cascade_id_generation.
	## as a result.
	## they don't exist when the name and id are assigned.
	## that is the problem.

=begin
	def set_accessors
		unless self.payable_from_organization_id.blank?
			self.payable_from_organization = Organization.find(self.payable_from_organization_id) 
			self.payable_from_organization.run_callbacks(:find)
		end

		unless self.payable_from_patient_id.blank?
			self.payable_from_patient = Patient.find(self.payable_from_patient_id) 
			self.payable_from_patient.run_callbacks(:find)
		end

		unless self.payable_to_organization_id.blank?
			self.payable_to_organization = Organization.find(self.payable_to_organization_id) 
			self.payable_to_organization.run_callbacks(:find)
		end

	end
=end
	def payable_from_organization_id=(payable_from_organization_id)
		puts "came to payable from organization id."
		unless payable_from_organization_id.blank?
			self.payable_from_organization = Organization.find(payable_from_organization_id) 
			self.payable_from_organization.run_callbacks(:find)
		end
		@payable_from_organization_id = payable_from_organization_id
	end

	def payable_to_organization_id=(payable_to_organization_id)
		puts "came to payable to organization id."
		unless payable_to_organization_id.blank?
			self.payable_to_organization = Organization.find(payable_to_organization_id) 
			self.payable_to_organization.run_callbacks(:find)
		end
		@payable_to_organization_id = payable_to_organization_id
	end

	def payable_from_patient_id=(payable_from_patient_id)
		puts "came to payable from patient id."
		unless payable_from_patient_id.blank?
			self.payable_from_patient = Patient.find(payable_from_patient_id)
			self.payable_from_patient.run_callbacks(:find)
		end
		@payable_from_patient_id = payable_from_patient_id
	end

	## @called_from : app/models/concerns/business/order_concern.rb#find_or_initialize_receipt
	def update_recipients
		unless self.payable_from_organization.blank?
			self.payable_from_organization.users_to_notify.each do |user|
				r = Notification::Recipient.new(user_id: user.id.to_s)
				unless self.has_matching_recipient?(r)
					self.recipients << r
				end
			end
		end

		unless self.payable_from_patient.blank?
			r = Notification::Recipient.new(patient_id: self.payable_from_patient.id.to_s)
			unless self.has_matching_recipient?(r)
				self.recipients << r
			end
		end

		unless self.payable_to_organization.blank?
			self.payable_to_organization.users_to_notify.each do |user|
				r = Notification::Recipient.new(user_id: user.id.to_s)
				unless self.has_matching_recipient?(r)
					self.recipients << r
				end
			end
		end

	end
	#####################################################
	##
	##
	## VALIDATIONS
	##
	##
	######################################################
	validate :mode_of_newly_added_payment

	validate :type_of_newly_added_payment


	def mode_of_newly_added_payment
		self.payments.select{|c|
			((c.new_record?) && (c.has_created_by_user_id?))
		}.each do |payment|
			if current_user_from_payable_from_org?
				self.errors.add(:payments, "payment mode: #{payment.payment_mode} is not allowed.") if (payment.is_physical?)
			end
		end
	end

	## so we did mode and type of newly added payment.
	## what about balance payment.
	## so if you add a payment is it newly added?
	## when it comes from remote, what is it?
	## it is loaded -> so falsified.
	## 
	def type_of_newly_added_payment
		self.payments.select{|c|
			((c.new_record?) && (c.has_created_by_user_id?))
		}.each do |payment|
			if payment.is_a_bill?
				self.errors.add(:payments,"you cannot add a bill directly")
			elsif payment.is_a_discount?

			end
		end
	end

	## is the patient organization getting created while
	## creating a patient
	## or the users organization 
	## if the user is a patient.
	## gotta sort this out.
	

	def self.permitted_params
		[:id,:payable_to_organization_id,:payable_from_organization_id,:payable_from_patient_id,{ :payments => Business::Payment.permitted_params }, :created_by_user_id, :currently_held_by_organization]
	end	

	def self.index_properties
		{
			payable_to_organization_id: {
				type: 'keyword'
			},
			payable_from_organization_id: {
				type: 'keyword'
			},
			payable_from_patient_id: {
				type: 'keyword'
			},
			payments: {
				type: 'nested',
				properties: Business::Payment.index_properties
			},
			total: {
				type: 'float'
			},
			paid: {
				type: 'float'
			},
			pending: {
				type: 'float'
			}
		}
	end

	## @called_from : order_concern#update_receipt_totals
	## if the payment has been marked as newly_created in config/initializers#hash, then we set the created_by_user, and created_by_user_id, as the current user from the order.
	def set_payment_created_by(current_user)
		self.payments.each do |payment|
			if !payment.is_a_bill?
				payment.created_by_user = current_user
				payment.created_by_user_id = current_user.id.to_s
			end
		end
	end

	## then we write other validations on the payment itself.
	## to check that nothing has changed.
	## except approved/declined for online payments.

	def has_bill?(payment)
		self.payments.select{|c|
			(c.for_report_id == payment.for_report_id) && (!c.is_cancelled?)
		}.size == 1
	end

	def add_bill(payment)
		#puts "Came to add bill for report: #{payment.for_report_name}"
		unless has_bill?(payment)
			self.payments << payment
			self.force_pdf_generation = true
		else
			## i think after hash assign.
			#puts "already has bill for : #{payment.for_report_name}, and its newly added is: #{payment.newly_added}"
		end
	end

	def add_payment(payment)
		self.payments << payment
		self.force_pdf_generation = true
	end

	## @called_from : order_concern#validation
	def parameter_other_than_payments_changed?
		#puts "the changed attributes are:"
		#puts self.changed_attributes.to_s
		return false if self.changed_attributes.blank?
		if self.changed_attributes.size > 1
			return true
		elsif self.changed_attributes.size == 1
			if self.changed_attributes[0].to_s != "payments"
				return true
			end 
		end
		return false
	end
	
	## called_from : 
	## a. order_concern#on_remove_report.
	## if a report is removed, then bills levied for it are 
	## also deducted.
	def cancel_payments(args={})
		return if args.blank?
		if args[:report]
			self.payments.each do |payment|
				if payment.is_a_bill?
					if payment.for_report_id == args[:report].id.to_s
						payment.cancel
						self.force_pdf_generation = true
					end
				end
			end
		end
	end

	def requires_total_update?
		result = [self.force_pdf_generation]
		result << self.newly_added
		if self.changed_array_attribute_sizes.include? :payments
			result << true
		else
			self.payments.each do |payment|
				if payment.newly_added == true
					result << true
				end
				if payment.changed_attributes.include? :status
					result << true
				end
			end
		end
		result.include? true
	end

	## @called_from : self#add_bill, self#add_payment, self#cancel_payments
	def update_total
		puts "came to update total --------------------->"
		return true unless requires_total_update?
		puts "Crossed update total --------------------->"
		self.total = 0
		self.pending = 0
		self.paid = 0
		self.payments.each do |payment|
			puts "Checking payment id: #{payment.id.to_s}"
			if payment.is_approved?
				if payment.is_a_bill?
					self.total += payment.amount
				else
					self.paid += payment.amount
				end
			else
				if payment.is_from_balance?
					## so i want to check if has_balance works
					## or not.
					## so i need to setup the controller specs.
					## nothing will move forwards otherwise.
					## then comes the dropdowns.
					## we change everything including the way
					## it is displayed.
					## i could sort it out.
					self.paid += payment.amount if has_balance?(payment.amount)
				end
			end
		end
		puts "crossed looking at transaction successfully"
		transaction_successfull = false
		self.pending = (self.total - self.paid)
		puts "pending is: #{self.pending}"
		## so this was successfully done.
		## so now the next issue is why the pdf url is not getting set.
		## because we are not doing the job.
		$redis.watch(get_race_condition_key_name)
			unless locked?
				result = $redis.multi do |multi|
					multi.set(get_race_condition_key_name,LOCKED)
					#begin
						## you call validate
						if self.save(validate: false)
							## even then the accessors will be washed off
							## 
							transaction_successfull = true
						else
							#self.errors.add(:payments, "failed to commit receipt")
							transaction_successfull = false
						end
					#rescue
					#	transaction_successfull = false
					
					#end
					multi.set(get_race_condition_key_name,UNLOCKED)
				end
				puts "multi result is:"
				## so if this is the result.
				puts result.to_s
				if result.blank?
					transaction_successfull = false
				elsif result.uniq != ["OK"]
					transaction_successfull = false
				else
					transaction_successfull = true
					#self.errors.add(:payments, "another payment is being made from your organization, please wait for it to complete, and try again later")
				end
			else
				puts "it was already locked---------"
				transaction_successfull = false
				#self.errors.add(:payments, "another payment is being made from your organization, please wait for it to complete, and try again later")
			end
		$redis.unwatch
		transaction_successfull
	end
	
	## so do we do UI or what ?
	## the dropdown and all that
	## and some design shennanigans
	## or i can do both.
	## then there will be the run.
	## and what about the payment -> with payumoney and the patient.
	## payment verification and approval.
	## it is all pending.
	## check transactions
	## check top up?
	## and who can approve and create payments.
	## then how the patient will make a payment.
	## and then the payumoney intergration from the older code.
	## so let me start with tests for transactions

	##############################################################
	##
	##
	## TO CALCULATE BILL RECEIPTS
	##
	##
	##############################################################
	def locked?
		puts "Came to check locked."
		if $redis.get(get_race_condition_key_name).blank?
			puts "the key is blank"
			false
		else
		   puts "key is not blank"
		   puts "key is: #{$redis.get(get_race_condition_key_name)}"
		   $redis.get(get_race_condition_key_name) == LOCKED
		end
	end

	## @called_from : self#update_total before the save command.
	def get_race_condition_key_name
		self.payable_from_organization_id.to_s + "-balance-lock"
	end

	def has_balance?(amount)
		#statement = payable_from_organization.get_organization_balance_statement(nil)
		#((statement.payable_from_organization_ids.first.pending < 0) && (statement.payable_from_organization_ids.first.pending.abs > amount))
		return true
	end

	########################################################### main problem is the payments -> 
	## if i can sort that out ->
	## with statements, and accessibility by 1st 
	## we are in the driving seat.
	## if that can be done, it is all done
	## as i get 15 days for status.
	## at least i target esr and electrolyte this week
	## and then exl and nephelometer, the next week
	## so we have interfacing done, then just LIS 
	## 
	## i can sit and do that.
	## but what about the excercise?
	##
	## NOTIFICATIONS
	##
	##
	##############################################################
	def before_send_notifications
		return true unless self.resend_recipient_ids.blank?
		return true unless self.force_send_notifications.blank?
		return false
	end	

	def build_var_hash
		if !self.payable_from_patient.blank?
			{
				:VAR1 => self.payable_from_patient.first_name,
				:VAR2 => self.payable_from_patient.last_name,
				:VAR3 => self.pdf_url,
				:VAR4 => self.payable_to_organization.name
			}
		elsif !self.payable_from_organization.blank?
			{
				:VAR1 => self.payable_from_organization.name,
				:VAR3 => self.pdf_url,
				:VAR4 => self.payable_to_organization.name
			}
		end
	end

	## sends notification, sms, and email to all the recipients, of the order
	## now we test -> force, resend, receipt notifications
	## and what happens in stuff like things being added/removed etc.
	## okay get it working for receipt.
	def send_notifications
		puts "------------- CAME TO SEND NOTIFICAITONS FOR RECEIPT ------------------"
		## we will have to override the gather recipients.
		## how to get the patient ?

		gather_recipients.each do |recipient|
			puts "recipient is: #{recipient}"
			recipient.phone_numbers.each do |phone_number|
				response = Auth::TwoFactorOtp.send_transactional_sms_new({
					:to_number => phone_number,
					:template_name => RECEIPT_UPDATED_TEMPLATE_NAME,
					:var_hash => build_var_hash,
					:template_sender_id => RECEIPT_UPDATED_SENDER_ID
				})
			end
			unless recipient.email_ids.blank?
				#puts "the recipient has email id"
				#puts recipient.email_ids.to_s
				email = OrderMailer.receipt(recipient,self,self.payable_to_organization.created_by_user)
	        	email.deliver_now
        	end
    	end
	end
	##############################################################
	##
	##
	## PDF GENERATION
	##
	##
	##############################################################
	def before_generate_pdf
		if self.newly_added == true	
			return true		
		else
			if self.prev_size["payments"] < self.current_size["payments"]
				self.force_pdf_generation = true
				#return true
			end
			if self.any_payment_status_changed?
				#return true
				self.force_pdf_generation = true 
			end
			return !self.force_pdf_generation.blank?
		end
	end


	def get_pdf_file_name
		
		time_stamp = Time.now.strftime("%b %-d_%Y")

		if !self.payable_from_organization_id.blank?
			return self.payable_to_organization_id + "_" + self.payable_from_organization_id + "_" + time_stamp 
		elsif !self.payable_from_patient_id.blank?
			return self.payable_to_organization_id + "_" + self.payable_from_patient_id + "_" + time_stamp
		end

	end

	
	## We never call this method directly
	## We call process_pdf.
	def generate_pdf
		
		file_name = get_pdf_file_name

		ac = ActionController::Base.new

		pdf = ac.render_to_string pdf: file_name,
	            template: "#{ Auth::OmniAuth::Path.pathify(self.class.name).pluralize}/pdf/show.pdf.erb",
	            locals: {:receipt => self, :organization => self.payable_to_organization},
	            layout: "pdf/application.html.erb",
            	quiet: true,
	            header: {
	            	html: {
	            		template:'/layouts/pdf/receipt_header.pdf.erb',
	            		layout: "pdf/application.html.erb",
	            		locals:  {:receipt => self, :organization => self.payable_to_organization}
	            	}
	            },
	            footer: {
	           		html: {   
	           			template:'/layouts/pdf/receipt_footer.pdf.erb',
	           			layout: "pdf/application.html.erb",
	            		locals: {:receipt => self, :organization => self.payable_to_organization}
	                }
	            }       

        save_path = Rails.root.join('public',"#{file_name}.pdf")
		File.open(save_path, 'wb') do |file|
		  file << pdf
		  self.pdf_urls = [save_path]
		  self.pdf_url = save_path
		end
		self.skip_pdf_generation = true
		
		after_generate_pdf


	end


	def after_generate_pdf
		send_notifications
	end

	## so let us make the templates
	## for prepaid and postpaid orders
	## and policy settings.
	#################################################################
	##
	##
	## OVERRIDES FROM FORM CONCERN -> to show nested objects.
	##
	##
	#################################################################
	def summary_row(args={})
		'
			<tr>
				<td>' + self.created_at.strftime("%b %-d_%Y") + '</td>
				<td>' + (self.payable_to_organization_id || "-") + '</td>
				<td>' + (self.payable_from_organization_id || "-") + '</td>
				<td>' + (self.payable_from_patient_id || "-") + '</td>
				<td>' + self.total.to_s + '</td>
				<td>' + self.paid.to_s + '</td>
				<td>' + self.pending.to_s + '</td>
				<td><div class="edit_nested_object"  data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		'''
			<thead>
	          <tr>
	              <th>Created At</th>
	              <th>Payable To Organization Id</th>
	              <th>Payable From Organization Id</th>
	              <th>Payable From Patient Id</th>
	              <th>Total</th>
	              <th>Paid</th>
	              <th>Pending</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	## if the root is an order, we don't want the add new button.
	def add_new_object(root,collection_name,scripts,readonly)
			
		if root =~ /order|statement/
			''
		else
			
			script_id = BSON::ObjectId.new.to_s

			script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
			
			scripts[script_id] = script_open

			scripts[script_id] +=  new_build_form(root + "[" + collection_name + "][]",readonly,"",scripts) + '</div></script>'
		
			element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"

			element

		end

	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["versions","owner_ids","active","public","created_at","updated_at","created_by_user_id","currently_held_by_organization","verified_by_user_ids","rejected_by_user_ids","name","payable_from_organization_id","payable_from_patient_id","payable_to_organization_id"]
		}
	end

	######################################################
	##
	##
	## OVERRIDEN FROM OWNERS CONCERN.
	##
	##
	######################################################
	def add_owner_ids
		self.owner_ids << self.payable_from_organization_id 
		self.owner_ids << self.payable_to_organization_id
		self.owner_ids << self.payable_from_patient_id
		self.owner_ids.compact!
		self.owner_ids.uniq!
	end


	######################################################
	##
	##
	## HELPERS FOR QUERIES FROM THE RECEIPTS_CONTROLLER.RB
	##
	##
	######################################################
	## @return[Boolean] true/false : true if we are only going to generate a summary of the data.
	## basically if any of the two from the array below are provided, we will simply show all the receipts that lie between from - to.
	## if only any one of the three are provided we generate a statement of summary like (either from/to that organzation id) => total pending, in the period specified, stratified by month. 
	def only_show_summary?
		count = 0	
		["payable_from_organization_id","payable_to_organization_id","payable_from_patient_id"].each do |k|
			count+=1 unless self.send(k.to_sym).blank?
		end
		count <= 1
	end	

	## @used_in : order_concern#generate_Receipt_pdfs
	## used to check if any of the payments statuses were changed
	## to regenerate the receipts.
	def any_payment_status_changed?
		#puts "came to check if any payment status changed."
		selected_payments = self.payments.select{|c|
			#puts "checking payment, changed attributes"
			#puts c.changed_attributes.to_s
			c.changed_attributes.include? "status"
		}
		#puts "selected payments are:"
		#puts selected_payments.to_s
		selected_payments.size > 0
	end

	############################################################
	###
	###
	### helpers used inside validations inside self.
	###
	############################################################
	def current_user_from_payable_to_org?
		self.current_user.organization.id.to_s == self.payable_to_organization_id
	end

	def current_user_from_payable_from_org?
		self.current_user.organization.id.to_s == self.payable_from_organization_id
	end

	

end