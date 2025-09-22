module HttpClient
  extend ActiveSupport::Concern

  included do
    def self.build_faraday_connection(url)
      Faraday.new(url: url) do |faraday|
        faraday.headers['User-Agent'] = 'summary.ecosyste.ms'
        faraday.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY'] && url.include?('.ecosyste.ms')
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
    end

    private

    def build_faraday_connection(url)
      self.class.build_faraday_connection(url)
    end
  end
end