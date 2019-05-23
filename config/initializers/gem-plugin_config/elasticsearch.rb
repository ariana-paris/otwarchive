$elasticsearch = Elasticsearch::Client.new host: ERB.new(ArchiveConfig.ES_URL).result
