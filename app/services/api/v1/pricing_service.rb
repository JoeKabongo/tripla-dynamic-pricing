module Api::V1
  class PricingService < BaseService
    CACHE_EXPIRY = 5.minutes
    RACE_TTL = 10.seconds

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
          parsed_rate['rates'].detect do |r|
            r['period'] == @period && r['hotel'] == @hotel && r['room'] == @room
          end&.dig('rate')
        else
          errors << rate.body['error']
          nil
        end
      end
    end

    private

    def create_cache_key
      "pricing:v1:#{@period}:#{@hotel}:#{@room}"
    end
  end
end
