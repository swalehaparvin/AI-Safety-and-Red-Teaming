#A lightweight tool for analyzing LLM probability distributions and interpretability.

#Run the pip command in terminal before running the code
pip install torch transformers accelerate


import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForCausalLM
tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2-0.5B")
model = AutoModelForCausalLM.from_pretrained( "Qwen/Qwen2-0.5B", torch_dtype=torch.float16,   device_map="auto")
Prompt = "1+1="
inputs = tokenizer(Prompt, return_tensors="pt").to(model.device)

with torch.no_grad():
    outputs = model(**inputs)
    logits = outputs.logits
    next_token_logits = logits[0, -1]
log_probs = F.log_softmax(next_token_logits, dim=-1)
top_k = 100
values, indices = torch.topk(log_probs, top_k)

print(f"Top predictions for {Prompt}:")
for v, i in zip(values, indices):
    token = tokenizer.decode([i])
    prob = torch.exp(v).item() * 100
    print(f"{token!r}: logprob={v.item():.4f}, prob={prob:.2f}%")