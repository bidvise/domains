class Domains::Schema
  class RequiredFieldsMissingError < Domains::Error; end

  class FieldTypeMismatchError < Domains::Error; end

  class EmptyFieldError < Domains::Error; end

  class UnpermittedFieldError < Domains::Error; end

  class IncorrectSchemaFormat < Domains::Error; end

  class IncorrectDataFormat < Domains::Error; end

  UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.freeze

  SchemaRepr = Struct.new(:doc, :fields, keyword_init: true)

  # Potentially refactor to subclasses of shared superclass:
  Field = Struct.new(:name, :type, :doc, :options, keyword_init: true)

  # Document the schema as a whole
  def self.schemadoc(docstring)
    @schemadoc = docstring
  end

  # Document the next field
  def self.doc(docstring)
    @most_recent_doc = docstring
  end

  # Define a field
  def self.field(name, type, options = {})
    field_info = Field[name: name.to_s, type: type, doc: @most_recent_doc, options: options]
    @most_recent_doc = nil

    @fields ||= []
    @fields << field_info
  end

  # Define a field containing an embedded sub-schema
  def self.embed(name, mod)
    raise IncorrectSchemaFormat, "Attempted to embed non-schema module #{mod.inspect}" unless mod.respond_to?(:schema)

    self.field(name, :value_object, { schema: mod.schema })
  end

  def self.embed_list(name, mod)
    raise IncorrectSchemaFormat, "Attempted to embed non-schema module #{mod.inspect}" unless mod.respond_to?(:schema)
    self.field(name, :list, { schema: mod.schema })
  end

  # Look at the created schema as a PORO
  def self.schema
    SchemaRepr[doc: @schemadoc, fields: @fields]
  end

  # Validate a hash to this schema
  def self.validate(data, require_strictly: false)
    validate_schema(schema, data, require_strictly: require_strictly)
  end

  # Validate a hash to the PORO schema `schema`
  private_class_method def self.validate_schema(schema, data, require_strictly: false)
    return data if schema.nil?

    data = data.to_unsafe_h if data.is_a?(ActionController::Parameters)

    raise IncorrectSchemaFormat, "Expected an array, got #{schema}" unless schema.fields.is_a?(Array)
    raise IncorrectDataFormat, "Expected a hash, got #{data.inspect}" unless data.is_a?(Hash)

    data = data.with_indifferent_access
    validate_required_fields(schema.fields, data) if require_strictly

    data.map { |key, value| validate_schema_field(schema.fields, key, value, require_strictly: require_strictly) }

    data
  end

  private_class_method def self.validate_required_fields(schema, data)
    required_field_names = schema.select { |field| field.options[:required] }.map(&:name)
    missing_field_names = required_field_names - data.keys.map(&:to_s)

    raise RequiredFieldsMissingError, "Missing required fields [#{missing_field_names.join(', ')}]" if missing_field_names.any?
  end

  def self.validate_schema_field(schema, key, value, require_strictly:)
    expected_schema = schema.find { |field| field[:name].to_s == key.to_s }
    raise UnpermittedFieldError, "#{key}, #{value}" unless expected_schema

    validate_type(expected_schema, value, require_strictly: require_strictly)
  end

  private_class_method def self.validate_type(field, value, require_strictly: false)
    return true if value.nil?
    case field[:type]
    when :string
      raise build_err(field, value, "string") unless value.is_a?(String)
      raise EmptyFieldError, "String field #{field[:name]} may not be empty" if field.options[:empty] == false && value.blank?
    when :uuid
      raise build_err(field, value, "uuid") unless value.is_a?(String) && UUID_REGEX.match?(value)
      # when :list
      #   raise build_err(field, value, "list") unless value.is_a?(Array)
    when :integer
      raise build_err(field, value, "integer") unless value.is_a?(Integer)
    when :boolean
      raise build_err(field, value, "boolean") unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
    when :datetime
      raise build_err(field, value, "datetime") unless value.is_a?(Time)
    when :enum
      raise build_err(field, value, "one of the possibilities in the enum") unless field.options[:enum_list].include?(value.to_sym)
    when :list
      raise build_err(field, value, "list") unless value.is_a?(Array)
      if field.options[:list_type]
        if field.options[:list_type] == :string
          raise build_err(field, value, "list of strings") unless value.all? { |v| v.is_a?(String) }
        else
          raise StandardError, "Unknown list type #{field.options[:list_type]}"
        end
      end
    when :reference
      # TODO
      raise build_err(field, value, "reference") unless value.is_a?(Object)
    when :value_object
      return true if value == {}

      expected_object_schema = field.options[:schema]
      validate_schema(expected_object_schema, value, require_strictly: require_strictly)
    else
      raise "Unknown type #{field[:type]}"
    end
  end

  private_class_method def self.build_err(field_schema, value, expectation)
    FieldTypeMismatchError.new("Expected a #{expectation}, but got #{value.inspect} (for field #{field_schema.inspect})")
  end
end
