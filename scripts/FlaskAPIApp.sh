#!/bin/bash

sudo apt update
sudo apt install python3
sudo apt install python3-pip

sudo ufw allow 5000/tcp

# Install Flask
pip install flask

# Create the Python file
cat <<EOL > app.py
from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

# Store the issues in a list
issues = []

# HTML template
html_template = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Issues</title>
  </head>
  <body>
    <h1>Issues:</h1>
    <ul>
      {% for issue in issues %}
        <li>{{ issue }}</li>
      {% endfor %}
    </ul>
  </body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(html_template, issues=issues)

@app.route('/api/add', methods=['POST'])
def add_issue():
    data = request.get_json()
    issue = data.get('issue')
    if issue:
        issues.append(issue)
        return jsonify({'message': 'Issue added successfully!'}), 200
    return jsonify({'message': 'No issue provided!'}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOL

# Run the Flask application
python app.py