class RateApiClient
  include HTTParty

  base_uri ENV.fetch("RATE_API_URL", "http://localhost:8080")
  headers "Content-Type" => "application/json"
  headers "token" => ENV.fetch("RATE_API_TOKEN", "04aa6f42aa03f220c2ae9a276cd68c62")

  TIMEOUT_SECONDS = 2
  OPEN_TIMEOUT_SECONDS = 0.5

  def self.get_rate(period:, hotel:, room:)
    params = {
      attributes: [
        {
          period: period,
          hotel: hotel,
          room: room
        }
      ]
    }.to_json
    post("/pricing",
         timeout: TIMEOUT_SECONDS,
         open_timeout: OPEN_TIMEOUT_SECONDS,
         body: params)
  end
end
