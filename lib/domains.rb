# frozen_string_literal: true

module Domains
  class Error < StandardError; end

  class InvalidInputError < Error; end
  class ResourceNotFoundError < Error; end
end

require_relative "domains/version"
require_relative "domains/message"
require_relative "domains/schema"
