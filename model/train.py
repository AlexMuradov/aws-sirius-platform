import torch, json
from transformers import AutoModelForSequenceClassification, AutoTokenizer

def save_model(model, path):
    # Save the trained model to a file
    model.save_pretrained(path)

def load_model(path):
    # Load the model from a file
    return AutoModelForSequenceClassification.from_pretrained(path)

# Define the model and tokenizer
model_name = "bert-base-uncased"
model_path = "saved_model"  # Set the path to save the trained model

try:
    # Try loading the model from the provided path
    model = load_model(model_path, num_labels=3)  # Set the number of labels
    print("Loaded model from:", model_path)
except:
    # If the provided model path does not exist, start from "bert-base-uncased"
    model = AutoModelForSequenceClassification.from_pretrained(model_name, num_labels=3)  # Set the number of labels
    print("Starting from 'bert-base-uncased' pre-trained model.")

tokenizer = AutoTokenizer.from_pretrained(model_name)

json_file = open('train.json')
json_str = json_file.read()
json_data = json.loads(json_str)

# data = {
#     "train_data": [
#         ("This is a positive sentence.", "positive"),
#         ("This is a negative sentence.", "negative"),
#         ("This is a neutral sentence.", "neutral"),
#     ],
#     "eval_data": [
#         ("This is a positive sentence.", "positive"),
#         ("This is a negative sentence.", "negative"),
#         ("This is a neutral sentence.", "neutral"),
#     ]
# }

# Load the training data
train_data = json_data["train_data"]

# Tokenize the training data
train_encodings = tokenizer(train_data, padding=True, truncation=True, return_tensors="pt", is_split_into_words=True)

# Prepare the input tensors
input_ids = train_encodings["input_ids"]
attention_mask = train_encodings["attention_mask"]
labels = torch.tensor([[1 if label in labels_list else 0 for label in ["positive", "negative", "neutral"]] for labels_list in train_data])

# Training the model
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-5)
loss_fn = torch.nn.BCEWithLogitsLoss()  # Use Binary Cross Entropy with Logits for multi-label classification

# Training loop
num_epochs = 10
for epoch in range(num_epochs):
    model.train()
    optimizer.zero_grad()

    outputs = model(input_ids, attention_mask=attention_mask)
    logits = outputs.logits
    loss = loss_fn(logits, labels.float())

    loss.backward()
    optimizer.step()

    print(f"Epoch {epoch+1}/{num_epochs}, Loss: {loss.item():.4f}")

# Save the trained model
save_model(model, model_path)

# Evaluate the model (same evaluation code as before)
eval_data = json_data["eval_data"]

eval_encodings = tokenizer(eval_data, padding=True, truncation=True, return_tensors="pt", is_split_into_words=True)

with torch.no_grad():
    model.eval()
    eval_input_ids = eval_encodings["input_ids"]
    eval_attention_mask = eval_encodings["attention_mask"]
    eval_labels = torch.tensor([[1 if label in labels_list else 0 for label in ["positive", "negative", "neutral"]] for labels_list in eval_data])

    eval_outputs = model(eval_input_ids, attention_mask=eval_attention_mask)
    logits = eval_outputs.logits
    eval_predictions = (torch.sigmoid(logits) > 0.5).long()  # Threshold at 0.5 for multi-label classification

    accuracy = (eval_predictions == eval_labels).sum().item() / (eval_labels.numel())
    print(f"Accuracy: {accuracy:.4f}")
