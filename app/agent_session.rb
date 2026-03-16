require 'descartes'
require_relative 'execution_tool_proxy'

class SubmitResultsToolProxy < Descartes::Tool::Base
  name :submit_results
  description "Submit the final SPSS syntax and analytical summary to complete the job."
  yields_control true
  parameters(
    type: "object",
    properties: {
      final_syntax: { type: "string", description: "The pure executable IBM SPSS syntax code." },
      analysis_summary: { type: "string", description: "The natural language analytical report." }
    },
    required: ["final_syntax", "analysis_summary"]
  )

  def execute(args)
    @context.set('final_syntax', args['final_syntax'])
    @context.set('analysis_summary', args['analysis_summary'])
    "Mission Accomplished."
  end
end

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
      tools: [ExecutionToolProxy, SubmitResultsToolProxy]
    )
  end

  def start
    @thread = Thread.new do
      begin
        prompt = "User Request: #{@init_data['prompt']}\n\nPlease generate and execute the appropriate IBM SPSS syntax to fulfill this request. Keep exploring until you succeed."
        
        # 阻塞调用 Descartes Agent 的内部 ReAct 循环
        result = @agent.execute(@context, prompt)
        
        # 因为 submit_results 工具会自动把内容写入 @context，我们直接从 context 中取结果
        final_syntax = @context.get('final_syntax') || "No syntax generated. (Agent Result: #{result})"
        analysis_summary = @context.get('analysis_summary') || "No analysis generated. (Agent Result: #{result})"
        
        @ws.send({
          type: 'finished',
          status: 'success',
          final_syntax: final_syntax,
          analysis_summary: analysis_summary
        }.to_json)
      rescue => e
        @ws.send({ type: 'error', message: "Agent Crash: #{e.message}\n#{e.backtrace.first(3).join("\n")}" }.to_json)
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
      
      Here is the pre-fetched Data Dictionary / Metadata for the active dataset:
      ---
      #{@init_data['working_note']}
      ---
      
      CRITICAL INSTRUCTIONS:
      0. DO NOT invoke `DISPLAY DICTIONARY.` or `SHOW VARIABLES.`. The dataset metadata is already provided to you above. Analyze it directly.
      1. You must iteratively use the `execute_spss` tool to test your code on the local dataset.
      2. If the syntax contains errors, the tool will return the SPSS output error message. You must reflect on the error, fix your syntax, and run the tool again.
      3. Once execution succeeds and the objective is met, you MUST use the `submit_results` tool to finish the job.
      4. Your `submit_results` tool payload MUST include BOTH properties:
         - `final_syntax`: MUST contain ONLY the pure, raw, complete executable IBM SPSS syntax code (no markdown wrappers like ```spss, no explanations, just the code).
         - `analysis_summary`: MUST contain a natural language analytical report summarizing the statistical findings you observed from the SPSS execution output.
    PROMPT
  end
end
