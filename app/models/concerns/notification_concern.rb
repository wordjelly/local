#notification_concern.rb
module Concerns::NotificationConcern

	extend ActiveSupport::Concern

	included do

		attribute :recipients, Array[Notification::Recipient], mapping: {type: 'nested', properties: Notification::Recipient.index_properties}

		attribute :additional_recipients, Array[Notification::Recipient], mapping: {type: 'nested', properties: Notification::Recipient.index_properties}

		attribute :disable_recipient_ids, Array

		attribute :resend_recipient_ids, Array

		attribute :ready_to_send_notification, Date, mapping: {type: 'date', format: 'epoch_second'}

		attr_accessor :skip_resend_notifications

		attr_accessor :force_send_notifications

		if defined? @permitted_params
  			if ((@permitted_params[1].is_a? Hash) && (self.class.name.to_s =~ /#{@permitted_params[1].keys[0]}/i))
				@permitted_params[1] = @permitted_params[1] + [:recipients => Notification::Recipient.permitted_params, :additional_recipients => Notification::Recipient.permitted_params]	
  			else
  				@permitted_params = @permitted_params + [:recipients => Notification::Recipient.permitted_params, :additional_recipients => Notification::Recipient.permitted_params]
  			end
  		else
  			@permitted_params = [:recipients => Notification::Recipient.permitted_params, :additional_recipients => Notification::Recipient.permitted_params]
  		end


		after_validation do |document|
			document.process_notification
		end

		after_save do |document|
			document.queue_notification_job
		end



	end

	#######################################################
	##
	##
	## DO NOT OVERRIDE
	##
	##
	#######################################################
	## this is the method called in the callback
	## after_Validation.
	def process_notification
		if before_send_notifications.blank?
			self.ready_to_send_notification = nil
		else
			self.ready_to_send_notification = Time.now.to_i 
		end
	end

	## then we come to this, and setu 

	def queue_notification_job
		## you can add it to the job.
		## any resend recipients are wiped at this stage.
		self.send_notifications unless self.ready_to_send_notification.blank?
		self.resend_recipient_ids = []
	end


	#######################################################
	##
	##
	## CAN OVERRIDE
	##
	##
	#######################################################
	def before_send_notifications
		return true unless self.resend_recipient_ids.blank?
		return true unless self.force_send_notifications.blank?
		return false
	end

	## TO BE OVERRIDEN
	def after_send_notifications

	end

	## TO BE OVERRIDDEN
	## called in the background job.
	def send_notifications

	end
	#######################################################
	##
	##
	## HELPER METHODS
	## 
	##
	#######################################################

	## collate the recipients, and additional recipients
	## automatically removes the disabled ids.
	def gather_recipients
		(self.recipients + self.additional_recipients).reject{|c| self.disable_recipient_ids.include? c.id.to_s}
	end

	## @return[Boolean] true/false a matching recipient exists
	## in this objects recipients.
	def has_matching_recipient?(recipient)
		self.gather_recipients.select{|c|
			c.matches?(recipient)
		}.size > 0
	end

end