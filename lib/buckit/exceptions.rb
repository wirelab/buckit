module Buckit

  class SyncException < StandardError
  end

  class WrongUsage < SyncException

    attr_accessor :error_code
    attr_accessor :msg

    def initialize(error_code, msg)
      @error_code = error_code || 1
      @msg = msg
    end
  end

  class FailureFeedback < SyncException
  end

end
