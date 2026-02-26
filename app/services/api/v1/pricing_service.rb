module Api::V1
  class PricingService < BaseService
    CACHE_EXPIRY = 5.minutes
    RACE_TTL = 10.seconds
    NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Timeout::Error,
                      SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].freeze

    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      cache_key = create_cache_key

      @result = Rails.cache.fetch(
        cache_key,
        expires_in: CACHE_EXPIRY,
        race_condition_ttl: RACE_TTL,
        skip_nil: true
      ) do
        rate = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)

        if rate.success?
          parsed_rate = JSON.parse(rate.body)

          matched_rate = parsed_rate["rates"].detect do |r|
            r["period"] == @period && r["hotel"] == @hotel && r["room"] == @room
          end&.dig("rate")

          if matched_rate.nil?
            @error_status = :not_found
            errors << "No rate found for the selected period, hotel, and room combination."
            nil
          end

          matched_rate

        else
          @error_status = map_upstream_status(rate.code)
          errors << rate.body["error"]
          nil
        end
      end
    rescue *NETWORK_ERRORS => e
      Rails.logger.error("Network error: #{e.class} (#{e.message})")
      @error_status = :service_unavailable
      errors << "Service is temporarily unavailable. Please try again later."
      @result = nil
    rescue StandardError => e
      Rails.logger.error("Standard error: #{e.message}")
      @error_status = :internal_server_error
      errors << "Something went wrong on our side. Please try again later."
      @result = nil
    end

    private

    def create_cache_key
      "pricing:v1:#{@period}:#{@hotel}:#{@room}"
    end

    def map_upstream_status(code)
      case code
      when 429
        :too_many_requests
      when 500..599
        :service_unavailable
      else
        :bad_request
      end
    end
  end
end
