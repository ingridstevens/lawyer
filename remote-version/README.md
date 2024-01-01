# German Residency Law Assistant - Remote Version

The Remote Version of the German Residency Law Assistant is hosted remotely, eliminating the need for local installations. Users can access and interact with the tool without dealing with additional dependencies.

## Accessing the Remote Version

1. No need to install Ollama or models locally.

2. Access the hosted version directly without any local setup.

3. Interact with the tool through the provided interface or API.

## Setting Up Environmental Variables

Before you start, you will need to set up the following environmental variables:

### Pinecone

1. **Create a Pinecone Account:**
   - If you don't have a Pinecone account, sign up [here](https://www.pinecone.io/).

2. **Create a Pinecone Index:**
   - After signing in, create a Pinecone index for the German Residency Law Assistant project.

3. **Retrieve Pinecone API Key, Environment, and Index:**
   - In your Pinecone dashboard, obtain the API Key, Environment, and Index details.
   - Set the following environmental variables:
     - `PINECONE_API_KEY`: Your Pinecone API Key.
     - `PINECONE_ENVIRONMENT`: Your Pinecone Environment.
     - `PINECONE_INDEX`: The name of the Pinecone Index you created.

### OpenAI

1. **Obtain OpenAI API Key:**
   - If you don't have an OpenAI account, sign up [here](https://beta.openai.com/signup/).
   - Retrieve your OpenAI API Key from the OpenAI dashboard.

2. **Set OpenAI API Key:**
   - Set the environmental variable:
     - `OPENAI_API_KEY`: Your OpenAI API Key.

## Libraries Used

Run `pip install -r requirements.txt` to install the necessary libraries.

## Using the Remote Version

Once you have set up the environmental variables, you can interact with the German Residency Law Assistant remotely. The tool uses Pinecone for indexing and retrieval, and OpenAI for language models.

---

## How does it work?

This is a RAG (Retrieval Augmented Generation) notebook utilizing open-source models to address legal questions about residency in Germany. It extracts information from the [Aufenthaltsverordnung (AufenthV)](https://www.gesetze-im-internet.de/aufenthv/BJNR294510004.html) and, in the future, the Aufenthaltsgesetz (AufenthG), responding to questions related to residency in Germany.

The notebook tokenizes and embeds the text of the AufenthV, enabling semantic search between user queries and legal text. The top results are then used to generate answers using an open-source LLM (Large Language Model). This allows users to interact with German legal content in English and receive responses in English.

### Functionality

- **Semantic Search:** The notebook conducts semantic searches between user queries and legal text, facilitating accurate information retrieval.
- **Multilingual Support:** Interaction with German legal text in English and vice versa is supported. Semantic search functions effectively across languages.
- **Customization:** Users can adapt the code to address questions on various legal topics by substituting the text of the AufenthV with the desired legal text.



## Setting Up Langsmith for Evaluation

To evaluate the German Residency Law Assistant using Langsmith, follow these steps:

### Langsmith

1. **Create a Langsmith Account:**
   - If you don't have a Langsmith account, sign up [here](https://langsmith.com/). - note that this is in beta, so you need to request access.

2. **Obtain Langsmith API Key and Project Name:**
   - After signing in, retrieve your LangChain API Key and Project Name from the Langsmith dashboard.

3. **Set Langsmith Environmental Variables:**
   - Before you start the evaluation, set the following environmental variables:
     - `LANGCHAIN_TRACING_V2=true`
     - `LANGCHAIN_API_KEY`: Your LangChain API Key.
     - `LANGCHAIN_PROJECT`: Your Langsmith Project Name.

### Using Langsmith for Evaluation

Once you have set up the Langsmith environmental variables, you can use Langsmith for evaluating the German Residency Law Assistant's performance.

Please refer to the [LangSmith Documentation](https://api.smith.langchain.com/redoc) for more information on how to use the tool.
