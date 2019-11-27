module Concerns::PdfConcern

	extend ActiveSupport::Concern

	included do 

		attribute :latest_version, String, mapping: {type: "keyword"}
		
		attribute :pdf_url, String, mapping: {type: "keyword"}
		## the cloudinary urls of files that were converted into pdfs
		attribute :pdf_urls, Array, mapping: {type: "keyword"}, default: []
			
		#attribute :pdf_generated_at, Date, mapping: {type: 'date', format: 'epoch_second'}
		## so if set, then a background job will read this value 
		## and generate and send the pdf.
		attribute :ready_for_pdf_generation, Date, mapping: {type: 'date', format: 'epoch_second'}

		attr_accessor :skip_pdf_generation
		## if true will be used.
		attr_accessor :force_pdf_generation

		if defined? @permitted_params
  			if ((@permitted_params[1].is_a? Hash) && (self.class.name.to_s =~ /#{@permitted_params[1].keys[0]}/i))
  				#puts "it is the first key hash---------->"
				@permitted_params[1] = @permitted_params[1] + [:force_pdf_generation]	
  			else
  				#puts "it is not---------->"
  				@permitted_params = @permitted_params + [:force_pdf_generation]
  			end
  		else
  			@permitted_params = [:force_pdf_generation]
  		end

		after_validation do |document|
			document.process_pdf
		end

		after_save do |document|
			
			ScheduleJob.perform_later([document.id.to_s,document.class.name,"pdf_job"])
			
		end

	end

	CLOUDINARY_RESULT_OK = "ok"
	CLOUDINARY_RESULT_NOT_FOUND = "not found"

	######################################################
	##
	##
	## FLOW FOR PDF GENERATION IS SIMPLE:
	## AFTER_VALIDATION ---> CONCERN CALLS PROCESS_PDF --> PROCESS PDF CHECKS IF BEFORE_GENERATE_PDF RETURNS TRUE -> THEN IT SETS READY_FOR_PDF GENERATION TO THE CURRENT TIME, OTHERWISE SETS IT TO NULL.
	##
	## AFTER_SAVE -> READY_FOR_PDF_GENERATION IS CHECKED, FOR NOT BEING NULL -> AND THAT IS used to trigger queue_pdf_job
	## the next time the record is saved, if the before_generate_pdf -> returns false, then after_save nothing will be triggered, so you can safely save it in the background job without worrying about endless repeats.
	##
	## now if you want to send notifications, then that is chained.
	## for the notification also we can follow a similar architecture, or use the same architeture are now.
	## notification ready_for_notification.
	## is set -> and that can be sent.
	## before set_notify
	## we call process_notify ->
	## which calls before_set_notify -> 
	## in case of resend -> will return true
	## in case of send -> nothing will be returned.
	## ready_to_renotify -> can be set -> and that can be called in a background job.
	## we just override that.
	######################################################
	## this is the main method to call.
	## internally will call the generate_pdf method inside the background job.
	def pdf_job
		unless self.ready_for_pdf_generation.blank?
			generate_pdf
			self.ready_for_pdf_generation = nil
			self.save(validate: false) 
		end
	end

	## now its firing the receipt issue.
	## its firing it from the receipt.
	## which is fine actually.
	## let it be different.
	## this shoulkd be called
	def process_pdf
		if before_generate_pdf.blank?
			self.ready_for_pdf_generation = nil
		else
			self.ready_for_pdf_generation = Time.now.to_i 
		end
	end

	## returns false by default.
	## 
	def before_generate_pdf
		return false unless self.skip_pdf_generation.blank?
		return false
	end

	def after_generate_pdf

	end

	## will set the pdf_uploaded_to_cloudinary_variable, to true, if the upload is successfull.
	## this is going to happen in a background job.
	def generate_pdf
			

		file_name = get_file_name
		file_name = "test"
	    
	    ac = ActionController::Base.new
	    
	    pdf = ac.render_to_string pdf: file_name,
            template: "#{ Auth::OmniAuth::Path.pathify(self.class.name).pluralize}/pdf/show.pdf.erb",
            locals: {:object => self},
            layout: "pdf/application.html.erb",
            quiet: true,
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
		after_generate_pdf

	end


	## @return[String] file_name : consists of a bson object id and the current time.
	def get_file_name
		BSON::ObjectId.new.to_s + "_" + Time.now.strftime("%b_%-d_%Y")
	end

end