class OrderMailer < Auth::Notifier
	
	def report(recipient,order,current_user)
		@order = order
		@resource = current_user
		mail to: recipient.email_ids, subject: I18n.t("pathofast_mailer_report_subject")
	end

	def receipt(recipient,receipt,current_user)
		@receipt = receipt
		@resource = current_user
		mail to: recipient.email_ids, subject:  I18n.t("pathofast_mailer_receipt_subject")
	end

end
