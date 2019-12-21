module StreamModule

	SECRET = ENV["FIREBASE_SECRET"]
	SITE_URL = ENV["FIREBASE_SITE"]

	attr_accessor :on_message_handler_function
	attr_accessor :connection
	attr_accessor :private_key_hash
	attr_accessor :event_source

	def setup_connection
		raise "please provide the private key hash, from firebase service account -> create private key " if self.private_key_hash.blank?
		raise "no event source endpoint provided" if self.event_source.blank?
		self.connection = RestFirebase.new :site => SITE_URL,
                     :secret => SECRET, :private_key_hash => private_key_hash, :auth_ttl => 1800
        self.on_message_handler_function ||= "on_message_handler"

	end

	def watch
		@reconnect = true
		es = self.connection.event_source(self.event_source)
		es.onopen   { |sock| p sock } # Called when connecte
		es.onmessage{ |event, data, sock| 
			puts "event is:#{event}"
			send(self.on_message_handler_function,data)
		}
		es.onerror  { |error, sock| p error } # Called 4
		es.onreconnect{ |error, sock| p error; @reconnect }
		es.start
		self.connection.wait

	end

	def on_message_handler(data)
		puts "got some data"
		puts data
	end

end