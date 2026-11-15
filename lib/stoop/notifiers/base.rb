# frozen_string_literal: true

module Stoop
  module Notifiers
    # Base class for notifiers. Subclasses implement +deliver(message)+.
    # Returns true on success. Raises NotifierError on failure; callers
    # decide whether to abort the run or continue with the next product.
    class Base
      def deliver(_message)
        raise NotImplementedError, "#{self.class} must implement #deliver"
      end
    end

    # Notifier error. The message must never include tokens or secrets.
    class NotifierError < StandardError; end
  end
end
