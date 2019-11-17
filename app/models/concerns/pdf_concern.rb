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

		after_validation do |document|
			document.process_pdf
		end

		after_save do |document|
			document.queue_pdf_job unless document.ready_for_pdf_generation.blank?
		end

	end

	CLOUDINARY_RESULT_OK = "ok"
	CLOUDINARY_RESULT_NOT_FOUND = "not found"

	## this is the main method to call.
	## internally will call the generate_pdf method inside the background job.
	def queue_pdf_job
		## we queue this shit later.
		## but we want to know if the tests pass or not.
		## so right now just let it 
		generate_pdf
		## after generating we have to knock it off
		## suppose it does not generate, and we want to 
		## regenerate ?
		## for whatever reason it fails ?
		#PdfJob.perform_later([self.class.name, self.id.to_s])
	end

	## this shoulkd be called
	def process_pdf
		self.ready_for_pdf_generation = Time.now.to_i unless before_generate_pdf.blank?
	end

	## returns false by default.
	## 
	def before_generate_pdf
		#puts "came to before generate pdf."
		#puts "pdf generated at is: #{self.pdf_generated_at}"
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