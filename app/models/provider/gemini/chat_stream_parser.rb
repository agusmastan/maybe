class Provider::Gemini::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    return nil if object.nil?

    # Check if this is a streaming chunk with text content
    candidates = object.dig("candidates")
    return nil unless candidates&.any?

    candidate = candidates.first
    content = candidate.dig("content")
    return nil unless content

    parts = content.dig("parts") || []

    # Check for text delta
    text_part = parts.find { |part| part.key?("text") }
    if text_part
      # Check if this is the final response (has usageMetadata)
      if object.key?("usageMetadata")
        Chunk.new(type: "response", data: parse_response(object))
      else
        Chunk.new(type: "output_text", data: text_part["text"])
      end
    end

    # Check for function calls
    function_call_part = parts.find { |part| part.key?("functionCall") }
    if function_call_part
      Chunk.new(type: "response", data: parse_response(object))
    end
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk

    def parse_response(response)
      Provider::Gemini::ChatParser.new(response).parsed
    end
end
