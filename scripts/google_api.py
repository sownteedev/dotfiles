import json
import urllib.request
import urllib.parse
import urllib.error
import time
import os
import sys
import datetime
import http.server
import secrets
import shutil

QUICKSHELL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_HOME = os.environ.get(
    "XDG_STATE_HOME",
    os.path.join(os.path.expanduser("~"), ".local", "state")
)
TOKEN_DIR = os.path.join(STATE_HOME, "quickshell")
TOKEN_FILE = os.path.join(TOKEN_DIR, "google-calendar-token.json")
LEGACY_TOKEN_FILE = os.path.join(QUICKSHELL_DIR, "google-calendar-token.json")


def ensure_token_storage():
    os.makedirs(TOKEN_DIR, mode=0o700, exist_ok=True)
    if os.stat(TOKEN_DIR).st_mode & 0o777 != 0o700:
        os.chmod(TOKEN_DIR, 0o700)


def migrate_legacy_token():
    if os.path.exists(TOKEN_FILE):
        if os.stat(TOKEN_FILE).st_mode & 0o777 != 0o600:
            os.chmod(TOKEN_FILE, 0o600)
        return
    if not os.path.exists(LEGACY_TOKEN_FILE):
        return

    ensure_token_storage()
    try:
        os.replace(LEGACY_TOKEN_FILE, TOKEN_FILE)
    except OSError:
        shutil.copy2(LEGACY_TOKEN_FILE, TOKEN_FILE)
        os.unlink(LEGACY_TOKEN_FILE)
    os.chmod(TOKEN_FILE, 0o600)

def read_token():
    migrate_legacy_token()
    if not os.path.exists(TOKEN_FILE):
        return None
    try:
        with open(TOKEN_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading token: {e}", file=sys.stderr)
        return None

def write_token(data):
    try:
        ensure_token_storage()
        temp_path = TOKEN_FILE + ".tmp"
        with open(temp_path, 'w') as f:
            json.dump(data, f, indent=2)
        os.chmod(temp_path, 0o600)
        os.replace(temp_path, TOKEN_FILE)
    except Exception as e:
        print(f"Error writing token: {e}", file=sys.stderr)


def auth_status():
    token_data = read_token() or {}
    access_valid = bool(
        token_data.get("access_token")
        and token_data.get("expires_at", 0) > int(time.time()) + 60
    )
    authenticated = bool(
        token_data.get("client_id")
        and (access_valid or token_data.get("refresh_token"))
    )
    print(json.dumps({"authenticated": authenticated}))


class OAuthCallbackHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if query.get("state", [""])[0] != self.server.oauth_state:
            self.server.oauth_error = "Invalid OAuth state"
            status = 400
            message = "Authentication failed: invalid state."
        elif query.get("error"):
            self.server.oauth_error = query["error"][0]
            status = 400
            message = "Google authentication was cancelled."
        else:
            self.server.oauth_code = query.get("code", [""])[0]
            status = 200 if self.server.oauth_code else 400
            message = ("Authentication complete. You can close this tab."
                       if self.server.oauth_code else "No authorization code received.")
        body = ("<!doctype html><meta charset='utf-8'><title>Quickshell Google Auth</title>"
                "<style>body{font-family:sans-serif;background:#101817;color:#e9f2f0;"
                "display:grid;place-items:center;height:100vh;margin:0}div{padding:32px;"
                "border-radius:18px;background:#182220}</style><div>" + message + "</div>")
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, _format, *_args):
        pass


def run_local_auth():
    try:
        credentials = json.loads(sys.stdin.readline())
    except (json.JSONDecodeError, TypeError):
        print(json.dumps({"event": "error", "message": "Invalid credentials payload"}))
        return 1

    client_id = str(credentials.get("client_id", "")).strip()
    client_secret = str(credentials.get("client_secret", "")).strip()
    if not client_id or not client_secret:
        print(json.dumps({"event": "error", "message": "Client ID and Client Secret are required"}))
        return 1

    server = http.server.HTTPServer(("127.0.0.1", 0), OAuthCallbackHandler)
    server.timeout = 1
    server.oauth_state = secrets.token_urlsafe(24)
    server.oauth_code = ""
    server.oauth_error = ""
    redirect_uri = f"http://127.0.0.1:{server.server_port}/oauth2callback"
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks",
        "access_type": "offline",
        "prompt": "consent",
        "state": server.oauth_state
    })
    print(json.dumps({"event": "authorization_url", "url": auth_url}), flush=True)

    deadline = time.monotonic() + 300
    while not server.oauth_code and not server.oauth_error and time.monotonic() < deadline:
        server.handle_request()
    server.server_close()

    if server.oauth_error:
        print(json.dumps({"event": "error", "message": server.oauth_error}), flush=True)
        return 1
    if not server.oauth_code:
        print(json.dumps({"event": "error", "message": "Authentication timed out"}), flush=True)
        return 1

    request_data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "code": server.oauth_code,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri
    }).encode("utf-8")
    request = urllib.request.Request(
        "https://oauth2.googleapis.com/token", data=request_data, method="POST"
    )
    request.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        print(json.dumps({"event": "error", "message": detail or str(error)}), flush=True)
        return 1
    except (urllib.error.URLError, TimeoutError) as error:
        print(json.dumps({"event": "error", "message": str(error)}), flush=True)
        return 1

    token_data = {
        "client_id": client_id,
        "client_secret": client_secret,
        "access_token": result.get("access_token"),
        "refresh_token": result.get("refresh_token"),
        "expires_at": int(time.time()) + result.get("expires_in", 3600)
    }
    if not token_data["access_token"]:
        print(json.dumps({"event": "error", "message": "Google returned no access token"}), flush=True)
        return 1
    write_token(token_data)
    print(json.dumps({"event": "success"}), flush=True)
    return 0

def refresh_token_if_needed(token_data):
    # Check if expired (assuming access_token is valid for 1 hour)
    # The token_data should have an "expires_at" field, if not, we can't easily check, so we try a request, or just refresh if it fails.
    # const expires_at = Math.floor(Date.now() / 1000) + result.expires_in;
    current_time = int(time.time())
    expires_at = token_data.get("expires_at", 0)
    
    if current_time >= expires_at - 60:
        if not token_data.get("refresh_token"):
            return None
        # Need refresh
        try:
            url = "https://oauth2.googleapis.com/token"
            data = urllib.parse.urlencode({
                "client_id": token_data.get("client_id", ""),
                "client_secret": token_data.get("client_secret", ""),
                "refresh_token": token_data.get("refresh_token", ""),
                "grant_type": "refresh_token"
            }).encode("utf-8")
            
            req = urllib.request.Request(url, data=data, method="POST")
            req.add_header("Content-Type", "application/x-www-form-urlencoded")
            
            with urllib.request.urlopen(req, timeout=20) as response:
                result = json.loads(response.read().decode("utf-8"))
                
                if "access_token" in result:
                    token_data["access_token"] = result["access_token"]
                    token_data["expires_at"] = current_time + result.get("expires_in", 3600)
                    write_token(token_data)
                    return token_data["access_token"]
        except urllib.error.URLError as e:
            print(f"Failed to refresh token: {e}", file=sys.stderr)
        return None

    return token_data.get("access_token")

def fetch_calendars(access_token):
    url = "https://www.googleapis.com/calendar/v3/users/me/calendarList"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")
    
    with urllib.request.urlopen(req, timeout=20) as response:
        result = json.loads(response.read().decode("utf-8"))
        calendars = []
        for item in result.get("items", []):
            if item.get("accessRole") != "none":
                calendars.append({
                    "id": item.get("id"),
                    "name": item.get("summary"),
                    "color": item.get("backgroundColor")
                })
        return calendars

def fetch_events_for_calendar(access_token, calendar_id, time_min, time_max):
    encoded_id = urllib.parse.quote(calendar_id)
    encoded_min = urllib.parse.quote(time_min)
    encoded_max = urllib.parse.quote(time_max)
    
    url = f"https://www.googleapis.com/calendar/v3/calendars/{encoded_id}/events?timeMin={encoded_min}&timeMax={encoded_max}&singleEvents=true&orderBy=startTime&maxResults=2500"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")
    
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.loads(response.read().decode("utf-8")).get("items", [])


def run_setup():
    token_data = read_token() or {}
    
    client_id = token_data.get("client_id")
    client_secret = token_data.get("client_secret")
    
    if not client_id or "YOUR_" in client_id:
        client_id = input("Enter Google Client ID: ").strip()
    if not client_secret or "YOUR_" in client_secret:
        client_secret = input("Enter Google Client Secret: ").strip()
        
    if not client_id or not client_secret:
        print("Error: Client ID and Secret are required!")
        sys.exit(1)
        
    redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    scope = "https://www.googleapis.com/auth/calendar%20https://www.googleapis.com/auth/tasks"
    
    auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?client_id={client_id}&redirect_uri={redirect_uri}&response_type=code&scope={scope}&access_type=offline&prompt=consent"
    
    print("\n=== Google API Setup ===")
    print("\n1. Please visit this URL in your browser to authorize:\n")
    print(auth_url)
    print("\n2. After authorizing, Google will give you an Authorization Code.")
    auth_code = input("\nEnter the Authorization Code: ").strip()
    
    if not auth_code:
        print("Error: Authorization Code is required!")
        sys.exit(1)
        
    print("\nExchanging code for tokens...")
    
    url = "https://oauth2.googleapis.com/token"
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "code": auth_code,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri
    }).encode("utf-8")
    
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
            
            token_data["client_id"] = client_id
            token_data["client_secret"] = client_secret
            token_data["access_token"] = result.get("access_token")
            token_data["refresh_token"] = result.get("refresh_token")
            token_data["expires_at"] = int(time.time()) + result.get("expires_in", 3600)
            
            write_token(token_data)
            print(f"\n✅ Success! Tokens saved to {TOKEN_FILE}")
            print("Quickshell will now automatically pick up the new tokens!")
            
    except urllib.error.HTTPError as e:
        print(f"\nError exchanging code: HTTP {e.code}")
        print(e.read().decode("utf-8"))
        sys.exit(1)


def fetch_all_events(month, year):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return
        
    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return
        
    try:
        calendars = fetch_calendars(access_token)
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        return
    
    # Fetch from Jan 1 of previous year to Dec 31 of next year
    start_date = datetime.datetime(year - 1, 1, 1, 0, 0, 0)
    end_date = datetime.datetime(year + 2, 1, 1, 0, 0, 0)
    
    time_min = start_date.astimezone().isoformat()
    time_max = end_date.astimezone().isoformat()
    
    all_events = []
    
    for cal in calendars:
        try:
            events = fetch_events_for_calendar(access_token, cal["id"], time_min, time_max)
        except Exception as error:
            print(json.dumps({"error": str(error)}))
            return
        for e in events:
            # Parse times
            start = e.get("start", {}).get("dateTime") or e.get("start", {}).get("date")
            end = e.get("end", {}).get("dateTime") or e.get("end", {}).get("date")
            
            all_events.append({
                "id": e.get("id"),
                "title": e.get("summary", "No Title"),
                "description": e.get("description", ""),
                "location": e.get("location", ""),
                "start": start,
                "end": end,
                "calendarId": cal["id"],
                "calendarName": cal["name"],
                "calendarColor": cal["color"],
                "allDay": "date" in e.get("start", {})
            })
            
    # Sort events by start time
    all_events.sort(key=lambda x: x["start"] if x["start"] else "")
    
    print(json.dumps(all_events))


def print_calendars():
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return
        
    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return
        
    try:
        calendars = fetch_calendars(access_token)
        print(json.dumps(calendars))
    except Exception as error:
        print(json.dumps({"error": str(error)}))


def create_event(json_data):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return
        
    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return
        
    try:
        form = json.loads(json_data)
        date_str = form.get("date")
        
        event_data = {
            "summary": form.get("title", "New Event")
        }
        if form.get("description"):
            event_data["description"] = form.get("description")
        if form.get("location"):
            event_data["location"] = form.get("location")
        
        if form.get("allDay", False):
            event_data["start"] = {"date": date_str}
            # End date must be the next day for allDay events
            end_date_obj = datetime.datetime.strptime(date_str, "%Y-%m-%d") + datetime.timedelta(days=1)
            event_data["end"] = {"date": end_date_obj.strftime("%Y-%m-%d")}
        else:
            start_time = form.get("startTime", "00:00")
            end_time = form.get("endTime", "01:00")
            event_data["start"] = {
                "dateTime": f"{date_str}T{start_time}:00+07:00",
                "timeZone": "Asia/Ho_Chi_Minh"
            }
            event_data["end"] = {
                "dateTime": f"{date_str}T{end_time}:00+07:00",
                "timeZone": "Asia/Ho_Chi_Minh"
            }
            
        calendar_id = form.get("calendarId", "primary")
        encoded_id = urllib.parse.quote(calendar_id)
        
        url = f"https://www.googleapis.com/calendar/v3/calendars/{encoded_id}/events"
        data = json.dumps(event_data).encode("utf-8")
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Authorization", f"Bearer {access_token}")
        req.add_header("Content-Type", "application/json")
        
        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
            print(json.dumps({"success": True, "id": result.get("id")}))
            
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)


def delete_event(calendar_id, event_id):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return
        
    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return
        
    try:
        encoded_cal = urllib.parse.quote(calendar_id)
        encoded_evt = urllib.parse.quote(event_id)
        
        url = f"https://www.googleapis.com/calendar/v3/calendars/{encoded_cal}/events/{encoded_evt}"
        req = urllib.request.Request(url, method="DELETE")
        req.add_header("Authorization", f"Bearer {access_token}")
        
        with urllib.request.urlopen(req, timeout=20) as response:
            print(json.dumps({"success": True}))
            
    except urllib.error.HTTPError as e:
        if e.code == 204: # 204 No Content is success for DELETE
            print(json.dumps({"success": True}))
        else:
            print(json.dumps({"error": str(e)}), file=sys.stderr)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)


def update_event(calendar_id, event_id, json_data):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return
        
    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return
        
    try:
        form = json.loads(json_data)
        date_str = form.get("date")
        
        event_data = {
            "summary": form.get("title", "Updated Event")
        }
        if form.get("description") is not None:
            event_data["description"] = form.get("description")
        if form.get("location") is not None:
            event_data["location"] = form.get("location")
            
        if form.get("allDay", False):
            event_data["start"] = {"date": date_str}
            end_date_obj = datetime.datetime.strptime(date_str, "%Y-%m-%d") + datetime.timedelta(days=1)
            event_data["end"] = {"date": end_date_obj.strftime("%Y-%m-%d")}
        else:
            start_time = form.get("startTime", "00:00")
            end_time = form.get("endTime", "01:00")
            event_data["start"] = {
                "dateTime": f"{date_str}T{start_time}:00+07:00",
                "timeZone": "Asia/Ho_Chi_Minh"
            }
            event_data["end"] = {
                "dateTime": f"{date_str}T{end_time}:00+07:00",
                "timeZone": "Asia/Ho_Chi_Minh"
            }
            
        encoded_cal = urllib.parse.quote(calendar_id)
        encoded_evt = urllib.parse.quote(event_id)
        
        url = f"https://www.googleapis.com/calendar/v3/calendars/{encoded_cal}/events/{encoded_evt}"
        data = json.dumps(event_data).encode("utf-8")
        # PATCH only updates the provided fields
        req = urllib.request.Request(url, data=data, method="PATCH")
        req.add_header("Authorization", f"Bearer {access_token}")
        req.add_header("Content-Type", "application/json")
        
        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
            print(json.dumps({"success": True, "id": result.get("id")}))
            
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)




def fetch_tasks(tasklist_id="@default"):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return

    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return

    try:
        url = f"https://tasks.googleapis.com/tasks/v1/lists/{tasklist_id}/tasks?showCompleted=true&showHidden=true"
        req = urllib.request.Request(url)
        req.add_header("Authorization", f"Bearer {access_token}")

        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
            tasks = result.get("items", [])
            print(json.dumps(tasks))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)

def create_task(tasklist_id, json_data):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return

    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return

    try:
        form = json.loads(json_data)
        task_data = {"title": form.get("title", "New Task")}
        if form.get("notes"):
            task_data["notes"] = form.get("notes")
        if form.get("due"):
            # Due must be RFC 3339 timestamp, but tasks API ignores time part
            task_data["due"] = f"{form.get('due')}T00:00:00.000Z"

        url = f"https://tasks.googleapis.com/tasks/v1/lists/{tasklist_id}/tasks"
        data = json.dumps(task_data).encode("utf-8")
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Authorization", f"Bearer {access_token}")
        req.add_header("Content-Type", "application/json")

        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
            print(json.dumps({"success": True, "id": result.get("id")}))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)

def update_task(tasklist_id, task_id, json_data):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return

    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return

    try:
        form = json.loads(json_data)
        task_data = {}
        if "title" in form:
            task_data["title"] = form["title"]
        if "notes" in form:
            task_data["notes"] = form["notes"]
        if "due" in form:
            if form["due"]:
                task_data["due"] = f"{form.get('due')}T00:00:00.000Z"
            else:
                task_data["due"] = None
        if "status" in form:
            task_data["status"] = form["status"]

        url = f"https://tasks.googleapis.com/tasks/v1/lists/{tasklist_id}/tasks/{task_id}"
        data = json.dumps(task_data).encode("utf-8")
        req = urllib.request.Request(url, data=data, method="PATCH")
        req.add_header("Authorization", f"Bearer {access_token}")
        req.add_header("Content-Type", "application/json")

        with urllib.request.urlopen(req, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
            print(json.dumps({"success": True, "id": result.get("id")}))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)

def delete_task(tasklist_id, task_id):
    token_data = read_token()
    if not token_data:
        print(json.dumps({"error": "No token file"}))
        return

    access_token = refresh_token_if_needed(token_data)
    if not access_token:
        print(json.dumps({"error": "No access token"}))
        return

    try:
        url = f"https://tasks.googleapis.com/tasks/v1/lists/{tasklist_id}/tasks/{task_id}"
        req = urllib.request.Request(url, method="DELETE")
        req.add_header("Authorization", f"Bearer {access_token}")

        with urllib.request.urlopen(req, timeout=20) as response:
            print(json.dumps({"success": True}))

    except urllib.error.HTTPError as e:
        if e.code == 204:
            print(json.dumps({"success": True}))
        else:
            print(json.dumps({"error": str(e)}), file=sys.stderr)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--auth-status":
        auth_status()
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--auth-local":
        sys.exit(run_local_auth())

    if len(sys.argv) > 1 and sys.argv[1] == "--setup":
        run_setup()
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--get-tasks":
        tasklist_id = sys.argv[2] if len(sys.argv) > 2 else "@default"
        fetch_tasks(tasklist_id)
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--create-task":
        tasklist_id = sys.argv[2] if len(sys.argv) > 2 else "@default"
        json_data = sys.argv[3] if len(sys.argv) > 3 else "{}"
        create_task(tasklist_id, json_data)
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--update-task":
        tasklist_id = sys.argv[2] if len(sys.argv) > 2 else "@default"
        task_id = sys.argv[3] if len(sys.argv) > 3 else ""
        json_data = sys.argv[4] if len(sys.argv) > 4 else "{}"
        if task_id:
            update_task(tasklist_id, task_id, json_data)
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--delete-task":
        tasklist_id = sys.argv[2] if len(sys.argv) > 2 else "@default"
        task_id = sys.argv[3] if len(sys.argv) > 3 else ""
        if task_id:
            delete_task(tasklist_id, task_id)
        sys.exit(0)


        
    if len(sys.argv) > 1 and sys.argv[1] == "--get-calendars":
        print_calendars()
        sys.exit(0)
        
    if len(sys.argv) > 1 and sys.argv[1] == "--create":
        json_data = sys.argv[2] if len(sys.argv) > 2 else "{}"
        create_event(json_data)
        sys.exit(0)
        
    if len(sys.argv) > 1 and sys.argv[1] == "--delete":
        calendar_id = sys.argv[2] if len(sys.argv) > 2 else "primary"
        event_id = sys.argv[3] if len(sys.argv) > 3 else ""
        if event_id:
            delete_event(calendar_id, event_id)
        sys.exit(0)
        
    if len(sys.argv) > 1 and sys.argv[1] == "--update":
        calendar_id = sys.argv[2] if len(sys.argv) > 2 else "primary"
        event_id = sys.argv[3] if len(sys.argv) > 3 else ""
        json_data = sys.argv[4] if len(sys.argv) > 4 else "{}"
        if event_id:
            update_event(calendar_id, event_id, json_data)
        sys.exit(0)
        
    if len(sys.argv) > 2:
        month = int(sys.argv[1]) # 1-12
        year = int(sys.argv[2])
        fetch_all_events(month, year)
    else:
        # Default to current month
        now = datetime.datetime.now()
        fetch_all_events(now.month, now.year)
