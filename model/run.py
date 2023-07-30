import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import json

def load_model(path, num_labels, label_names):
    # Load the model from a file
    model = AutoModelForSequenceClassification.from_pretrained(path, num_labels=num_labels)

    # Set the label names in the model configuration
    model.config.id2label = {i: label for i, label in enumerate(label_names)}
    model.config.label2id = {label: i for i, label in enumerate(label_names)}

    return model

def predict_labels(model, tokenizer, input_text):
    # Tokenize the input text
    inputs = tokenizer(input_text, padding=True, truncation=True, return_tensors="pt")

    # Perform the prediction
    with torch.no_grad():
        model.eval()
        outputs = model(**inputs)
        logits = outputs.logits

    # Apply sigmoid for multi-label classification
    sigmoid = torch.nn.Sigmoid()
    probabilities = sigmoid(logits)

    # Get the label names from the model configuration
    label_names = list(model.config.id2label.values())

    # Prepare the JSON output
    output_json = []
    for label_name, probability in zip(label_names, probabilities.squeeze().tolist()):
        output_json.append({"label": label_name, "probability": probability})

    return output_json

# Define the model and tokenizer
model_name = "bert-base-uncased"
model_path = "./tmp"  # Set the path to the saved model checkpoint
num_labels = 3  # Set the number of labels, same as during training
label_names = ["positive", "negative", "neutral"]  # Set the label names used during training

# Load the model
model = load_model(model_path, num_labels, label_names)
tokenizer = AutoTokenizer.from_pretrained(model_name)

# Example text to predict labels for
input_text = "This is a weather is very good and nice."

# Get the predicted labels in JSON format
predicted_labels_json = predict_labels(model, tokenizer, input_text)
print(json.dumps(predicted_labels_json, indent=2))
