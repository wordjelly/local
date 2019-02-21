remote_host = {host: ENV["REMOTE_ES_HOST"] , scheme: 'https', port: 9243}
remote_host.merge!({user: ENV["REMOTE_ES_USER"], password: ENV["REMOTE_ES_PASSWORD"]})

$remote_es_client = Elasticsearch::Client.new hosts: [ remote_host], headers: {"Content-Type" => "application/json" }, request: { timeout: 45 }

host = {host: 'localhost', scheme: 'http', port: 9200}

Elasticsearch::Persistence.client = Elasticsearch::Client.new hosts: [ host], headers: {"Content-Type" => "application/json" }, request: { timeout: 145 }
