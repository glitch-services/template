import requests

PORT = 1234
TIMEOUT = 10

# Public data is data shown on the scoreboard (limited debug information so teams know how to fix failing checks - should be empty for passing checks)
# Private data is secret data passed from the put() check to the get() check, such as checker account credentials (and can be updated by the get() check if needed for later checks)
# Success is a boolean indicating whether the check passed or failed
# Random flag IDs are provided to the put() check, but can be overriden if desired and returned as a fourth argument from put() (e.g. to make flagIDs look like email addresses or if they are determined by the service)

# Returns (public, private, success)
def check(host: str):
    try:
        response = requests.get(f'http://{host}:{PORT}', timeout=TIMEOUT)
        if response.status_code != 200:
            return ('unexpected status code ' + str(response.status_code), '', False)
        return ('', '', True)
    except:
        return ('connection error', '', False)

# Returns (public, private, success) - or (public, private, success, flag_id) if flag_id is modified by the checker
def put(host: str, flag: str, flag_id: str):
    try:
        response = requests.post(f'http://{host}:{PORT}/items/{flag_id}/{flag}', timeout=TIMEOUT)
        if response.status_code != 200:
            return ('unexpected status code ' + str(response.status_code), '', False)
        if "token" not in response.json():
            return ('token not found', '', False)
        token = response.json()['token']
        return ('', token, True)
    except:
        return ('connection error', '', False)

# Returns (public, private, success)
def get(host: str, flag: str, flag_id: str, private: str):
    try:
        response = requests.get(f'http://{host}:{PORT}/items/{flag_id}?token={private}', timeout=TIMEOUT)
        if response.status_code != 200:
            return ('unexpected status code ' + str(response.status_code), '', False)
        if response.json()['item'] != flag:
            return ('flag does not match', '', False)
        return ('', '', True)
    except:
        return ('connection error', '', False)

