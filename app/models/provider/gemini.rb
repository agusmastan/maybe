class Provider::Gemini < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Gemini::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[gemini-2.5-flash gemini-1.5-pro gemini-1.5-flash]

  def initialize(api_key)
    @client = ::Gemini.new(
      credentials: {
        service: "generative-language-api",
        api_key: api_key
      },
      options: {
        model: "gemini-2.5-flash",
        server_sent_events: true
      }
    )
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      collected_chunks = []

      # Proxy that converts raw stream to "LLM Provider concept" stream
      stream_proxy = if streamer.present?
        proc do |chunk, _parsed, _raw|
          parsed_chunk = ChatStreamParser.new(chunk).parsed

          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end
      else
        nil
      end

      request_params = {
        contents: chat_config.build_contents(prompt),
        generationConfig: {
          responseMimeType: "text/plain"
        }
      }

      # Add system instruction if provided
      if instructions.present?
        request_params[:system_instruction] = { parts: { text: instructions } }
      end

      # Add tools if functions provided
      if chat_config.tools.present?
        request_params[:tools] = chat_config.tools
      end

      if stream_proxy.present?
        # Streaming mode
        client.stream_generate_content(request_params, stream: stream_proxy)

        # Find the response chunk in collected chunks
        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response_chunk&.data
      else
        # Non-streaming mode
        raw_response = client.generate_content(request_params)
        ChatParser.new(raw_response, model: model).parsed
      end
    end
  end

  private
    attr_reader :client
end
