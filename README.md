# Not a German Lawyer 
Disclaimer: this is not a lawyer, and is not meant to be used as one. This tool is meant to help bridge the information gap between the German legal system and the average person. It is not meant to be used as a substitute for a lawyer.

![German Lawyer](/img/german-law.jpeg)

## Overview

This guide provides detailed instructions on setting up and running the German Residency Law Assistant project. Ensure you follow each step to have the necessary libraries installed and successfully execute the notebook.

## Setup Steps

1. Navigate to the directory you want to be in for this project

2. (Optional: create a virtual environment **venv** and activate it):

`python -m venv venv`

`source venv/bin/activate`

3. Clone the repository:

`git clone https://github.com/ingridstevens/lawyer.git`

`cd lawyer`

`pip install -r requirements.txt`

4. Run Jupyer Notebook:

`jupyter notebook`

Navigate to the notebook `rag-residence-law.ipynb` and run the cells.

## Libraries Used

**The project utilizes the following Python libraries:**

- langchain: Language processing library (custom)
- qdrant: Vector database library

## Downloads Required 

**The project relies on Ollama for embeddings and language modeling:**
- [Ollama](https://ollama.ai): Embeddings and language modeling library
    - install mistral (or your model of choice) with `ollama run mistral`

---- 

## How does it work?

This is a RAG (Retrieval Augmented Generation) notebook that uses open source models to answer legal questions about residency in Germany. It is a RAG which takes information from the [Aufenthaltsverordnung (AufenthV)](https://www.gesetze-im-internet.de/aufenthv/BJNR294510004.html) and (in the future) the Aufenthaltsgesetz (AufenthG) and answers questions about residency in Germany.

This notebook splits, tokenizes, and embeds the text of the AufenthV and does a semantic search between a user query (i.e. "How long can I stay in Germany?") and the text of the AufenthV. It then uses the top n results to generate an answer to the question using an open source LLM.
This means that you can interact with the law (which is written in German) in English and get an answer to your question also in English.
Semantic search (wonderfully) seems to work very well across languages, so you can also ask questions in German and get an answer in German.

You can use this notebook to answer questions about residency in Germany. You can also use it to answer questions about other topics, but you will need to change the text of the AufenthV to the text of the law you want to use.

### Functionality 

- **Semantic Search:** The notebook splits, tokenizes, and embeds the text of the AufenthV, enabling semantic search between user queries and legal text.
- **Multilingual Support:** You can interact with the German legal text in English, and vice versa. Semantic search functions well across languages.
- **Customization:** Users can modify the code to answer questions on different legal topics by replacing the text of the AufenthV with the desired law.

**Some example questions you can ask:**
- How long can I stay in Germany?
- How long can I stay in Germany if I am a student?
- How long can I stay in Germany if I am a student and I have a job?
- How do I get a Blue Card?

## How do I run it?
You can run this notebook locally on your computer. For this to work, you will need Ollama installed and running a local model. You can adjust the code in the notebook `rag-residence-law.ipynb` to reflect the model you want to use.

## Ongoing TO DOs
- [ ] Try out different vector databases (Qdrant is suspiciously slow)
- [ ] Try out different models (e.g. orca 2, giraffe, mixtral, etc.)
- [ ] Add in more files (e.g. AufenthG)
