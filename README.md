# Not a German Lawyer 
Disclaimer: this is not a lawyer, and is not meant to be used as one. This tool is meant to help bridge the information gap between the German legal system and the average person. It is not meant to be used as a substitute for a lawyer.

![German Lawyer](/img/german-law.jpeg)

# Evaluation
I took the [list of FAQs from the German Federal Foreign Office website](https://www.auswaertiges-amt.de/en/visa-service/buergerservice/faq/-/606852?openAccordionId=item-606664-0-panel) and used them to evaluate the model. 

There are two sets of questions, one is in questions.txt the other in questions_2.txt.

They are both in English, but the laws are in German. This does not appear to be a problem.


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


#### IF USING THE LOCAL VERSION (Install Ollama & Models)

##### Downlaods Required: Install Ollama & Models
 
- download Ollama from [here](https://ollama.ai) and follow the instructions to install it.
- download the models you want to use. this notebook uses the following models and the models can be installed by running the following commands:
    - mistral `ollama run mistral`

For a complete list of models: `ollama list` or visit [ollama.ai/library](https://ollama.ai/library)


4. Run Jupyer Notebook:

`jupyter notebook`

Navigate to the notebook `rag-residence-law.ipynb` and run the cells.

## Libraries Used

Run `pip install -r requirements.txt`, to install the required libraries.

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

