require 'descartes'
require_relative 'execution_tool_proxy'

class AgentSession
  def initialize(ws, init_data)
    @ws = ws
    @init_data = init_data
    @queue = Thread::Queue.new
    
    @context = Descartes::Context.new({
      ws: @ws,
      ws_queue: @queue,
      dataset_schema: @init_data['schema']
    })
    
    # 假设使用 default 或 openai, 取决于 ruby_llm 配置 (可通过 ENV 或配置文件注入)
    # 此处假设用户环境变量已配置相应 profile，暂设为默认。
    llm_profile = ENV['SPSS_AGENT_LLM_PROFILE'] || 'glm'
    
    @agent = Descartes::Agent::Base.new(
      name: :spss_expert,
      profile_name: llm_profile,
      system_prompt: build_system_prompt,
      tools: [ExecutionToolProxy]
    )
  end

  def start
    @thread = Thread.new do
      begin
        prompt = "User Request: #{@init_data['prompt']}\n\nPlease generate and execute the appropriate IBM SPSS syntax to fulfill this request. Keep exploring until you succeed."
        
        # 阻塞调用 Descartes Agent 的内部 ReAct 循环
        result = @agent.execute(@context, prompt)
        
        # 当模型调用 `send_message` (yield_control) 退出循环后:
        # The agent.execute returns the final response which might contain the arguments directly
        # If the agent yielded control via send_message, the result will be a ToolCallResult
        if result.is_a?(Descartes::ToolCallResult) && result.tool_name == 'send_message'
          # The arguments for send_message are typically an array of hashes, e.g., [{"key": "final_syntax", "value": "..."}]
          # Or, if the LLM is smart, it might provide a single hash {final_syntax: "...", analysis_summary: "..."}
          # We need to parse the arguments to extract the required keys.
          
          final_syntax = "No final syntax provided by agent."
          analysis_summary = "No analysis summary provided by agent."

          # Try to parse the arguments from the tool call result
          if result.arguments.is_a?(Array)
            result.arguments.each do |arg|
              if arg.is_a?(Hash)
                if arg['key'] == 'final_syntax'
                  final_syntax = arg['value']
                elsif arg['key'] == 'analysis_summary'
                  analysis_summary = arg['value']
                end
              end
            end
          elsif result.arguments.is_a?(Hash) # Handle case where LLM provides a single hash
            final_syntax = result.arguments['final_syntax'] if result.arguments.key?('final_syntax')
            analysis_summary = result.arguments['analysis_summary'] if result.arguments.key?('analysis_summary')
          end
          
          @ws.send({
            type: 'finished',
            status: 'success',
            final_syntax: final_syntax,
            analysis_summary: analysis_summary
          }.to_json)
        else
          # Fallback if agent didn't use send_message or result is unexpected
          final_syntax = @context.get('final_syntax') || result.to_s
          analysis_summary = @context.get('analysis_summary') || "Agent finished without explicit summary."
          
          @ws.send({
            type: 'finished',
            status: 'success',
            final_syntax: final_syntax,
            analysis_summary: analysis_summary
          }.to_json)
        end
      rescue => e
        @ws.send({ type: 'error', message: "Agent Crash: #{e.message}" }.to_json)
      end
    end
  end

  def handle_execution_result(data)
    # 解除 ExecutionToolProxy 中的 queue.pop 挂起
    @queue.push(data)
  end

  private

  def build_system_prompt
    <<~PROMPT
      You are an expert IBM SPSS data analyst and programmer.
      Your task is to write SPSS syntax (.sps) to solve the user's data request.
      
      You have access to a remote execution tool `execute_spss` that allows you to run SPSS code on the user's computer against their secure dataset.
      
      Here is the User's Dataset Schema (Metadata):
      #{@init_data['schema']}
      
      CRITICAL INSTRUCTIONS:
      1. You must iteratively use the `execute_spss` tool to test your code on the local dataset.
      2. If the syntax contains errors, the tool will return the SPSS output error message. You must reflect on the error, fix your syntax, and run the tool again.
      3. Once execution succeeds and the objective is met, you MUST use the `send_message` tool.
      4. Your `send_message` tool payload MUST include TWO key-value pairs (or you must call it twice if limited to one key):
         - `key: "final_syntax"` -> The `value` MUST contain ONLY the pure, raw, complete executable IBM SPSS syntax code (no markdown wrappers like ```spss, no explanations, just the code).
         - `key: "analysis_summary"` -> The `value` MUST contain a natural language analytical report summarizing the statistical findings you observed from the SPSS execution output.
    PROMPT
  end
end
