require 'net/http'

module Capistrano
  module Harrow
    class HTTP
      def get(url, headers, params)
        params = URI.encode_www_form(params)
        request = Net::HTTP::Get.new(url.merge(params))
        headers.each do |header, value|
          request[header.to_s] = value
        end

        make_request request
      end

      def post(url, headers, data)
        request = Net::HTTP::Post.new(url)
        headers.each do |header, value|
          request[header.to_s] = value
        end
        request.body = data

        make_request request
      end

      private

      def make_request(request)
        http = Net::HTTP.new(request.uri.host, request.uri.port)
        http.use_ssl = request.uri.scheme == 'https'
        http.request(request)
      end
    end
  end
end
