name: traces
version: "0.1.0"
description: "Publish Hermes sessions to Traces on session and LLM lifecycle events."
author: "shunkakinoki"
hooks:
  - on_session_start
  - on_session_end
  - pre_llm_call
  - post_llm_call
