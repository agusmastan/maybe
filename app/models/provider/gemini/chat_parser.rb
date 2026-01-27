class Provider::Gemini::ChatParser
  Error = Class.new(StandardError)

  def initialize(object, model: nil)
    @object = object
    @model = model
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: @model || "gemini-2.0-flash",
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      # Gemini doesn't return a response ID like OpenAI, generate one
      SecureRandom.uuid
    end

    def messages
      candidates = object.dig("candidates") || []

      candidates.filter_map do |candidate|
        content = candidate.dig("content")
        next unless content

        parts = content.dig("parts") || []
        text_parts = parts.filter { |part| part.key?("text") }

        next if text_parts.empty?

        ChatMessage.new(
          id: SecureRandom.uuid,
          output_text: text_parts.map { |part| part["text"] }.join("\n")
        )
      end
    end

    def function_requests
      candidates = object.dig("candidates") || []

      candidates.flat_map do |candidate|
        content = candidate.dig("content")
        next [] unless content

        parts = content.dig("parts") || []
        function_call_parts = parts.filter { |part| part.key?("functionCall") }

        function_call_parts.map do |part|
          function_call = part["functionCall"]
          ChatFunctionRequest.new(
            id: SecureRandom.uuid,
            call_id: SecureRandom.uuid,
            function_name: function_call["name"],
            function_args: function_call["args"]&.to_json || "{}"
          )
        end
      end.compact
    end
end
