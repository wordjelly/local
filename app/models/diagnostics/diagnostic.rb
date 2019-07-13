class Diagnostics::Diagnostic
	def self.recreate_all_indices
		Diagnostics::Report.create_index! force: true
	end
end