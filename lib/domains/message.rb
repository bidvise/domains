# Purpose: Parent class to Queries and Commands
# This class is responsible for handling errors and exceptions
# that are raised by the child classes.

class Domains::Message

  include Domains::Helper
  class << self

    def singleton_method_added(name)
      return if name == :singleton_method_added
      return if @recursive_call
      return if self.private_methods.include?(name)

      @recursive_call = true

      original_method = self.singleton_method(name)
      @original_methods ||= {}
      @original_methods[name] = original_method

      self.define_singleton_method(name) do |*args, &block_arg|
        begin
          original_method.call(*args, &block_arg)
        rescue ActiveRecord::RecordInvalid => e
          raise Domains::InvalidInputError, e.message
        end
      end
      # NOTE: Calling `ruby2_keywords` is necessary to fix warnings.
      # If we go to Ruby 3.x (and drop support for 2.x) we can clean this up
      # c.f. https://eregon.me/blog/2021/02/13/correct-delegation-in-ruby-2-27-3.html
      self.singleton_class.send(:ruby2_keywords, name) if self.singleton_class.respond_to?(:ruby2_keywords, true)

      @recursive_call = false
      super
    end
  end
end
