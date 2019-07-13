module Concerns::Diagnostics::OutsourceConcern

	extend ActiveSupport::Concern

  	included do

  		## okay so we will have to add all this to the index_propertie.s
  		## and also the basic mapping.
  		## which organization is it to be outsourced to.
		attribute :outsource_to_organization_id, String, mapping: {type: 'keyword'}

		## you can give this also.
		attribute :outsource_from_status_category, String, mapping: {type: 'keyword'}

		## in the outsourced organizations procedure, from which status id do you want the outsourcing.
		attribute :outsource_from_status_id, String, mapping: {type: 'keyword'}

		## here i want statuses of the outsourced report.
		## that is the only way to deal with them.
		attribute :outsourced_report_statuses, Array[Diagnostics::Status], mapping: {
			type: 'nested',
			properties: Diagnostics::Status.index_properties
		}

		## the merged statuses by merging the reports of the internal and outsourcing organization.
		attribute :merged_statuses, Array[Diagnostics::Status], mapping: {
			type: 'nested',
			properties: Diagnostics::Status.index_properties
		}

		before_save do |document|
			document.copy_outsourced_report_statuses
			document.merge_outsourced_report_statuses
		end

  	end

  	def get_outsourced_report
  		unless self.outsource_to_organization_id.blank?
			search_request = Diagnostics::Report.search({
					query: {
						bool: {
							must: [
								{
									term: {
										owner_ids: self.outsource_to_organization_id
									}
								},
								{
									match: {
										"name.raw".to_sym => self.name
									}
								}
							]
						}
					}
			})

			unless search_request.response.hits.hits.blank?
				return search_request.response.hits.hits.first
			end
		end
  	end

  	## will first check if the outsourced report statuses are full or not.
  	## and then will copy them over.
  	def copy_outsourced_report_statuses
  		if outsourced_report = get_outsourced_report
  			if self.outsourced_report_statuses.blank?
  				self.outsourced_report_statuses = outsourced_report.statuses
  			end
  		end
  	end


  	def merge_outsourced_report_statuses
  		## get all the statuses before the current status.
  		## and proceed.
  		merged_statuses = []
		unless self.outsource_from_status_id.blank?
			self.outsourced_report_statuses.each do |status|
				break if status.id.to_s == self.outsource_from_status_id
				## where do we add the effective statuses ?
				## we compose a totally new array.
				if status.required?
					## do we have a status of this category
					if current_status = get_status_by_category(status.category)
							## add the to_be_performed_by
							merged_statuses << current_status
					else
							## basically the status of the referral(outsourced/big) organization will now be performed by the current(small/referring) organization. 
							status.performing_organization_id = self.created_by_user.organization.id.to_s
							merged_statuses << status
					end
				end
			end
		else
			unless self.outsource_from_status_category.blank?
				self.outsourced_report_statuses.each do |status|

					break if status.category == self.outsource_from_status_category

					if status.required?
					## do we have a status of this category
						if current_status = get_status_by_category(status.category)
								## add the to_be_performed_by
								merged_statuses << current_status
						else
								## basically the status of the referral(outsourced/big) organization will now be performed by the current(small/referring) organization. 
								status.performing_organization_id = self.created_by_user.organization.id.to_s
								merged_statuses << status
						end
					end	
				end
			end
		end
		self.merged_statuses = merged_statuses if self.merged_statuses.blank?
	end

	def get_status_by_category(category)
		statuses = self.statuses.select{|c| c.category == category}
		if statuses.size > 0
			statuses.first
		end
	end

	## let me see how it merges the reports
	## using a category and a status id.
	## so we make two organizations and let one outsource
	## to the other.
	## statuses have to answer required, and have to have a category.			

end