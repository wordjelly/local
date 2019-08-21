module ApplicationHelper
	
	## @return[Organization] signing_organization : the organization whose representatives will sign on the report.
	def get_signing_organization(reports)

		first_report = report.first

		results = {
			:signing_organization => nil
		}

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

end