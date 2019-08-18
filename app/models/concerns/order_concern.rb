module Concerns::OrderConcern

	extend ActiveSupport::Concern

	included do 
			
		attribute :name, String, mapping: {type: 'keyword'}

		attribute :reports, Array[Diagnostics::Report]

		attribute :patient_id, String, mapping: {type: 'keyword'}

		attr_accessor :patient

		attribute :categories, Array[Inventory::Category] 

		attribute :payments, Array[Business::Payment]
		## a new report chosen is first added to these
		## then internally is used to load the relevant report
		## and populate the reports array.
		attribute :template_report_ids, Array, mapping: {type: 'keyword'}

		attribute :local_item_group_id

		attribute :procedure_versions_hash, Hash

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
			      		:type => "texabrat",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
			      	}
			    }

			   	indexes :categories, type: 'nested', properties: Inventory::Category.index_properties
			   	indexes :reports, type: 'nested', properties: Diagnostics::Report.index_properties

			end

		end

		## do this on order.
		## only.
		validate :can_modify

		validate :tests_verified_by_authorized_users_only

		## this should happen before the validations.
		## not after.
		before_validation do |document|
			document.update_reports
			document.load_patient
			document.update_requirements
			document.update_report_items
			document.add_report_values
			document.verify
			document.set_accessors
			document.generate_pdf
		end

		after_find do |document|
			document.load_patient
			document.set_accessors
		end

	end

		
	## validation called from self.
	def tests_verified_by_authorized_users_only
		self.changed_attributes.each do |attr|
			if attr.to_s == "reports"
				self.reports.each do |r|
					if r.changed_attributes.include? "tests"
						r.tests.each do |test|
							if test.changed_attributes.include? "verification_done"
								## can the current user do this ?

							end
						end
					end
				end
			end
		end
	end	


	def current_can_verify_test?(report,test) 
		
		report_issuer_organization = Organization.find(report.currently_held_by_organization_id)

		

	end

	## @called from : self, it is a validation.
	def can_modify
		self.changed_attributes.each do |attr|
			if attr.to_s == "reports"
				## reports were edited.
				## for each report, if it has changed attributes
				## check and add.
				## don't need to dive further in.
				self.reports.each do |r|
					unless r.changed_attributes.blank?
						if r.owner_ids.include? self.created_by_user_id
						elsif r.owner_ids.include? self.created_by_user.organization.id.to_s
						else
							self.errors.add(:reports,"You cannot edit #{attr.name.to_s}")
						end
					end
				end		
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

	## sets the accessors of order, if any, and also those of the
	## child elements.
	def set_accessors
		self.reports.each do |report|
			report.set_accessors
			report.tests.each do |test|
				test.set_accessors
			end
		end
	end

	def update_reports
		## problem is here.
		self.reports.delete_if { |c|


			!self.template_report_ids.include? c.id.to_s
		}


		existing_report_ids = self.reports.map{|c|
			c.id.to_s
		}

		self.template_report_ids.each do |r_id|
			unless existing_report_ids.include? r_id
				report = Diagnostics::Report.find(r_id)
				report.created_by_user = User.find(report.created_by_user_id)
				report.run_callbacks(:find)
				self.reports << report
			end
		end

	end

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
	def reset_category_quantities
		self.categories.map {|cat|
			cat.quantity = 0	
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
		reset_category_quantities
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
									
								puts "the existing category quantity is: #{existing_category.quantity}"

								puts "the category quantity is: #{category.quantity}"

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
			
			category.set_item_report_applicability(self.reports)
			category.items.each do |item|
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

	## next step is to display the created report
	## for now just let me make something simple.
	## called before save, to add the patient values
	def add_report_values
		unless self.patient.blank?
			self.reports.map{|report|
				report.tests.map{|test|
					test.add_result(self.patient) 
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

	##############################################################
	##
	##
	## OVERRIDE GENERATE PDF.
	##
	##
	##############################################################
	def generate_pdf
			
		return unless self.skip_pdf_generation.blank?

		file_name = get_file_name
		file_name = "test"
	    
	    ac = ActionController::Base.new

	    ## we have to pass organization
	    ## reports
	    ## reports will have to carry a signed by.
	    ## that will be used to sign it.
	    ## that can be picked up from the report itself.

	    
	    pdf = ac.render_to_string pdf: file_name,
            template: "#{ Auth::OmniAuth::Path.pathify(self.class.name).pluralize}/pdf/show.pdf.erb",
            locals: {:object => self},
            layout: "pdf/application.html.erb",
            header: {
            	html: {
            		template:'/layouts/pdf/header.html.erb',
            		layout: '/layouts/pdf/empty_layout.html.erb',
            		locals: {:object => self}
            	}
            },
            footer: {
           		html: {   
           			template:'/layouts/pdf/footer.html.erb',
           			layout: '/layouts/pdf/empty_layout.html.erb',
            		locals: {:object => self}
                }
            }       

        save_path = Rails.root.join('public',"#{file_name}.pdf")
		File.open(save_path, 'wb') do |file|
		  file << pdf
		end
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


	module ClassMethods

		def permitted_params
			base = [
					:id,
					{:order => 
						[
							:name,
							{:template_report_ids => []},
							:patient_id,
							:local_item_group_id,
							:start_epoch,
							{
								:categories => Inventory::Category.permitted_params
							},
					    	{
					    		:payments => Business::Payment.permitted_params
					    	},
					    	{
					    		:reports => Diagnostics::Report.permitted_params[1][:report]
					    	},
					    	:procedure_versions_hash
						]
					}
				]
			if defined? @permitted_params
				base[1][:order] << @permitted_params
				base[1][:order].flatten!
			end
			base
		end

	end

end