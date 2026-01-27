class Provider::Gemini::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  def tools
    return nil if functions.empty?

    [
      {
        function_declarations: functions.map do |fn|
          {
            name: fn[:name],
            description: fn[:description],
            parameters: convert_to_gemini_schema(fn[:params_schema])
          }
        end
      }
    ]
  end

  def build_contents(prompt)
    contents = [
      { role: "user", parts: [ { text: prompt } ] }
    ]

    # Add function results if any
    function_results.each do |fn_result|
      contents << {
        role: "model",
        parts: [ {
          functionCall: {
            name: fn_result[:function_name],
            args: {}
          }
        } ]
      }

      contents << {
        role: "function",
        parts: [ {
          functionResponse: {
            name: fn_result[:function_name],
            response: {
              result: fn_result[:output]
            }
          }
        } ]
      }
    end

    contents
  end

  private
    attr_reader :functions, :function_results

    # Convert OpenAPI-style JSON Schema to Gemini's schema format
    def convert_to_gemini_schema(schema)
      return nil if schema.nil?

      converted = {}

      converted[:type] = schema[:type]&.upcase || schema["type"]&.upcase
      converted[:description] = schema[:description] || schema["description"] if schema[:description] || schema["description"]

      properties = schema[:properties] || schema["properties"]
      if properties
        converted[:properties] = properties.transform_values { |v| convert_to_gemini_schema(v) }
      end

      required = schema[:required] || schema["required"]
      converted[:required] = required if required

      items = schema[:items] || schema["items"]
      converted[:items] = convert_to_gemini_schema(items) if items

      enum_values = schema[:enum] || schema["enum"]
      converted[:enum] = enum_values if enum_values

      converted
    end
end
