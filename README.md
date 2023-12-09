# German Lawyer 
Disclaimer: this is not a lawyer, and is not meant to be used as one. This tool is meant to help bridge the information gap between the German legal system and the average person. It is not meant to be used as a substitute for a lawyer.

## What is this?
This is a RAG (Retrieval Augmented Generation) notebook that uses open source models to answer legal questions about residency in Germany. It is a RAG which takes information from the [Aufenthaltsverordnung (AufenthV)](https://www.gesetze-im-internet.de/aufenthv/BJNR294510004.html) and (in the future) the Aufenthaltsgesetz (AufenthG) and answers questions about residency in Germany.

## How does it work?
This notebook splits, tokenizes, and embeds the text of the AufenthV and does a semantic search between a user query (i.e. "How long can I stay in Germany?") and the text of the AufenthV. It then uses the top n results to generate an answer to the question using an open source LLM.

## How do I use it?
You can use this notebook to answer questions about residency in Germany. You can also use it to answer questions about other topics, but you will need to change the text of the AufenthV to the text of the law you want to use.

## How do I run it?
You can run this notebook locally on your computer. For this to work, you will need Ollama installed and running a local model. You can adjust the code in the notebook `rag-residence-law.ipynb` to reflect the model you want to use.



