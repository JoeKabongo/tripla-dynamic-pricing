require "test_helper"

class Api::V1::PricingServiceTest < ActiveSupport::TestCase
  def setup
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
  end

  def teardown
    Rails.cache = @original_cache
  end

  test "fetches rate from API when no cache exists" do
    mock_body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "Resort", "room" => "Single", "rate" => "15000" }
      ]
    }.to_json
    mock_response = OpenStruct.new(success?: true, body: mock_body)

    RateApiClient.stub(:get_rate, mock_response) do
      service = Api::V1::PricingService.new(period: "Summer", hotel: "Resort", room: "Single")
      service.run

      assert_equal "15000", service.result
      assert service.valid?
      assert_empty service.errors
    end
  end

  test "serves rate from cache on subsequent identical calls" do
    mock_body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "Resort", "room" => "Single", "rate" => "5000" }
      ]
    }.to_json
    mock_response = OpenStruct.new(success?: true, body: mock_body)

    RateApiClient.stub(:get_rate, mock_response) do
      Api::V1::PricingService.new(period: "Summer", hotel: "Resort", room: "Single").run
    end

    RateApiClient.stub(:get_rate, ->(**_) { raise "API should not be called" }) do
      service = Api::V1::PricingService.new(period: "Summer", hotel: "Resort", room: "Single")
      service.run
      assert_equal "5000", service.result
    end
  end

  test "uses unique cache keys for different parameters" do
    mock_body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "Resort", "room" => "Single", "rate" => "5000" },
        { "period" => "Winter", "hotel" => "Resort", "room" => "Single", "rate" => "10000" }
      ]
    }.to_json
    mock_response = OpenStruct.new(success?: true, body: mock_body)

    RateApiClient.stub(:get_rate, mock_response) do
      service = Api::V1::PricingService.new(period: "Summer", hotel: "Resort", room: "Single")
      service.run
      assert_equal "5000", service.result

      service = Api::V1::PricingService.new(period: "Winter", hotel: "Resort", room: "Single")
      service.run
      assert_equal "10000", service.result
    end
  end

  test "does not cache nil results to allow immediate retries" do
    empty_body = { "rates" => [] }.to_json
    mock_response = OpenStruct.new(success?: true, body: empty_body)

    call_count = 0
    RateApiClient.stub(:get_rate, lambda { |**_|
      call_count += 1
      mock_response
    }) do
      service = Api::V1::PricingService.new(period: "Summer", hotel: "Invalid", room: "None")

      service.run
      assert_nil service.result
      assert_equal 1, call_count

      service.run
      assert_nil service.result
      assert_equal 2, call_count
    end
  end

  test "refreshes cache from API after expiration" do
    mock_body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "Resort", "room" => "Single", "rate" => "15000" }
      ]
    }.to_json
    mock_response = OpenStruct.new(success?: true, body: mock_body)

    call_count = 0
    RateApiClient.stub(:get_rate, lambda { |**_|
      call_count += 1
      mock_response
    }) do
      Api::V1::PricingService.new(period: "Summer", hotel: "Resort", room: "Single").run
      assert_equal 1, call_count

      travel(Api::V1::PricingService::CACHE_EXPIRY + 1.minute) do
        Api::V1::PricingService.new(period: "Summer", hotel: "Resort", room: "Single").run
        assert_equal 2, call_count
      end
    end
  end
end
