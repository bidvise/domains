# frozen_string_literal: true

require_relative "domains/version"

module Domains
  class Error < StandardError; end

  class InvalidInputError < Error; end
  class SiteNotFoundError < Error; end
  class RecordNotFoundError < Error; end
end
