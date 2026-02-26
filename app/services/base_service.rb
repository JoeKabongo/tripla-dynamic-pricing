class BaseService
  attr_accessor :result
  attr_reader :error_status

  def valid?
    errors.blank?
  end

  def errors
    @errors ||= []
  end
end
