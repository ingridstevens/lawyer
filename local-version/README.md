# German Residency Law Assistant - Local Version

This version of the German Residency Law Assistant is designed for users who prefer to run the tool on their local machines. It involves the installation of additional components such as Ollama and specific models.

## Setup Steps

1. Navigate to the desired project directory.

2. (Optional: create a virtual environment **venv** and activate it):

    ```bash
    python -m venv venv
    source venv/bin/activate
    ```

3. Clone the repository:

    ```bash
    git clone https://github.com/ingridstevens/lawyer.git
    cd lawyer
    pip install -r requirements.txt
    ```

### Download Ollama & Models

- Download Ollama from [here](https://ollama.ai) and follow the installation instructions.
- Download the required models. Run the following commands:

    ```bash
    ollama run mistral
    ```

    For a complete list of models: `ollama list` or visit [ollama.ai/library](https://ollama.ai/library).

4. Run Jupyter Notebook:

    ```bash
    jupyter notebook
    ```

    Navigate to the notebook `rag-residence-law.ipynb` and execute the cells.

## Libraries Used

Run `pip install -r requirements.txt` to install the necessary libraries.

---

## How does it work?

This is a RAG (Retrieval Augmented Generation) notebook utilizing open-source models to address legal questions about residency in Germany. It extracts information from the [Aufenthaltsverordnung (AufenthV)](https://www.gesetze-im-internet.de/aufenthv/BJNR294510004.html) and, in the future, the Aufenthaltsgesetz (AufenthG), responding to questions related to residency in Germany.

The notebook tokenizes and embeds the text of the AufenthV, enabling semantic search between user queries and legal text. The top results are then used to generate answers using an open-source LLM (Large Language Model). This allows users to interact with German legal content in English and receive responses in English.

### Functionality

- **Semantic Search:** The notebook conducts semantic searches between user queries and legal text, facilitating accurate information retrieval.
- **Multilingual Support:** Interaction with German legal text in English and vice versa is supported. Semantic search functions effectively across languages.
- **Customization:** Users can adapt the code to address questions on various legal topics by substituting the text of the AufenthV with the desired legal text.
