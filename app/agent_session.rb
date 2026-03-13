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
    llm_profile = ENV['SPSS_AGENT_LLM_PROFILE'] || 'openai'
    
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
        @ws.send({
          type: 'finished',
          final_syntax: result.to_s
        }.to_json)
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
      2. If the syntax contains errors, the tool will return the SPSS output error message. You must reflect on the error, fix your syntax, and run the tool again until execution succeeds and the output makes sense.
      3. Once you have successfully achieved the user's goal, you should summarize the final syntax working solution and submit your work using the `send_message` tool to yield control back to the user.
    PROMPT
  end
end
