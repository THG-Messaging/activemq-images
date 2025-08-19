import requests
from flask import Flask, jsonify

# Flask app setup
app = Flask(__name__)


JOLOKIA_URL = "http://localhost:8161/api/jolokia/read/org.apache.activemq:brokerName=BROKER_NAME,type=Broker/Slave"
USERNAME = "admin"
PASSWORD = "ACTIVEMQ_ADMIN_PASS"
SLAVE = "false" 


def check_jolokia_value():
    """Checks the Jolokia endpoint for the specified value."""
    try:
        # Make the GET request with basic authentication
        response = requests.get(JOLOKIA_URL, auth=(USERNAME, PASSWORD), timeout=10)
        response.raise_for_status()

        # Parse the JSON response
        data = response.json()

        # Check if 'value' key exists and matches the expected value
        if 'value' in data and data['value'] == SLAVE:
            return True, data['value']
        return False, data.get('value')
    except requests.RequestException as e:
        print(f"Error checking Jolokia endpoint: {e}")
        return False, None


@app.route("/check", methods=["GET"])
def check_endpoint():
    """Endpoint to check if the value exists and retrieve it."""
    exists, value = check_jolokia_value()
    return jsonify({"slave": value})


if __name__ == "__main__":
    # Run the Flask app
    app.run(host="0.0.0.0", port=8081)

