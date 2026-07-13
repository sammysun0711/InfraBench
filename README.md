## InfraBench: 
Benchmarking and Routing AI Agents for Production AI Infrastructure Engineering Tasks

### Introduction:
AI agents are effective for chatbots, documentation, and general software development, but leveraging them for production-grade AI infrastructure (AI Infra) engineering, especially on emerging hardware, remains an open challenge. This paper introduces InfraBench, a benchmark for evaluating AI agents on real-world AI Infra tasks targeting AMD MI35X GPUs, alongside a routing strategy that assigns each task to its most suitable model. Problem statement: How can we benchmark AI agents on real-world AI Infra tasks and route each task to the model achieving the best trade-off across success rate, latency, and cost? 

### Method:
We design a benchmark of 20 AI Infra tasks with available tools across five categories: model deployment, profiling analysis, kernel implementation, kernel tuning, and debug triage. Inspired by Terminal-Bench, agents operate in a Docker sandbox exposing a terminal interface. Each task is specified in natural language and verified by deterministic scripts. We evaluate frontier models (Claude, Codex) and open-source models through a unified LLM gateway, then compute a weighted efficiency score (success rate and latency) against inverse cost, applying a Pareto-frontier heuristic that recommends the most cost-effective model exceeding an efficiency threshold.

### Conclusions:
InfraBench charts a path toward self-improving infrastructure engineering, where agent trajectories become reusable assets for future agents.
