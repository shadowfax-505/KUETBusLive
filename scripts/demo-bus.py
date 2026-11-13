#!/usr/bin/env python3
#
#  demo-bus.py
#  KUETBusLive
#
#  Created by Muttakin Rahman Shoscho.
#
#  A pretend bus for demos on the local Firebase emulators. It never touches the
#  real project: it only talks to 127.0.0.1.
#
#    firebase emulators:start --only auth,firestore
#    python3 scripts/demo-bus.py seed     # a rider account and the Sonadanga route
#    python3 scripts/demo-bus.py drive    # the bus drives the route, round and round
#    python3 scripts/demo-bus.py drive crowded   # the same, reported overcrowded by a rider on board
#
#  Then run the app from Xcode with the environment variable USE_FIREBASE_EMULATORS=1
#  and sign in as demo-rider@test.com / busride2026.
#
#  The bus follows the real roads: the script asks OSRM (the same router the app
#  uses for ETAs) for the road path through the stops and moves along it at
#  25 km/h, sending a position every 5 seconds like the driver app does.
#

import json
import math
import sys
import time
import urllib.request

PROJECT = "kuetbuslive"
AUTH = f"http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1"
STORE = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"

EMAIL = "demo-rider@test.com"
PASSWORD = "busride2026"

STOPS = [
    ("KUET Main Gate", "কুয়েট মেইন গেট", 22.8999, 89.5024),
    ("Fulbarigate", "ফুলবাড়ীগেট", 22.8890, 89.5095),
    ("Daulatpur", "দৌলতপুর", 22.8660, 89.5170),
    ("Notun Rasta", "নতুন রাস্তা", 22.8460, 89.5330),
    ("Sonadanga Bus Terminal", "সোনাডাঙ্গা বাস টার্মিনাল", 22.8170, 89.5440),
]
MY_STOP = STOPS[2]

SPEED = 25 / 3.6   # metres per second
STEP = 5           # seconds between positions


def call(method, url, body=None, owner=False):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
    if owner:
        # The emulator lets "owner" skip the security rules.
        request.add_header("Authorization", "Bearer owner")
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def value(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [value(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: value(x) for k, x in v.items()}}}
    if isinstance(v, str) and v.startswith("TS:"):
        return {"timestampValue": v[3:]}
    return {"stringValue": v}


def put(path, fields):
    call("PATCH", f"{STORE}/{path}", {"fields": {k: value(v) for k, v in fields.items()}}, owner=True)


def seed():
    try:
        user = call("POST", f"{AUTH}/accounts:signUp?key=demo",
                    {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True})
    except urllib.error.HTTPError:
        user = call("POST", f"{AUTH}/accounts:signInWithPassword?key=demo",
                    {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True})
    uid = user["localId"]
    # Mark the email verified, so the rider doesn't stop at the email-link screen.
    call("POST", f"{AUTH}/projects/{PROJECT}/accounts:update",
         {"localId": uid, "emailVerified": True}, owner=True)
    put(f"users/{uid}", {"name": "Demo Rider", "email": EMAIL, "role": "student",
                         "kuetId": "2007001", "isApproved": True, "active": True,
                         "favoriteStopName": MY_STOP[0], "favoriteStopLat": MY_STOP[2],
                         "favoriteStopLng": MY_STOP[3]})
    put("routes/r-sonadanga", {"name": "KUET to Sonadanga", "nameBn": "কুয়েট থেকে সোনাডাঙ্গা",
                               "stops": [{"name": n, "nameBn": bn, "lat": lat, "lng": lng}
                                         for n, bn, lat, lng in STOPS]})
    print(f"Seeded {EMAIL} (password {PASSWORD}) and the Sonadanga route.")


def metres(a, b):
    x = (b[1] - a[1]) * 111320 * math.cos(math.radians(a[0]))
    y = (b[0] - a[0]) * 111320
    return math.hypot(x, y)


def bearing(a, b):
    la1, la2 = math.radians(a[0]), math.radians(b[0])
    dl = math.radians(b[1] - a[1])
    y = math.sin(dl) * math.cos(la2)
    x = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def road():
    coords = ";".join(f"{lng},{lat}" for _, _, lat, lng in STOPS)
    url = f"https://router.project-osrm.org/route/v1/driving/{coords}?overview=full&geometries=geojson"
    request = urllib.request.Request(url, headers={"User-Agent": "kuetbuslive-demo"})
    with urllib.request.urlopen(request) as response:
        line = json.load(response)["routes"][0]["geometry"]["coordinates"]
    return [(lat, lng) for lng, lat in line]


def point_along(path, distance):
    # The point `distance` metres down the path, and the direction of the road there.
    for a, b in zip(path, path[1:]):
        length = metres(a, b)
        if length > 0 and distance <= length:
            t = distance / length
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), bearing(a, b)
        distance -= length
    a, b = path[-2], path[-1]
    return b, bearing(a, b)


def drive(crowded=False):
    path = road()
    total = sum(metres(a, b) for a, b in zip(path, path[1:]))
    print(f"Road path: {len(path)} points, {total / 1000:.1f} km. Driving at 25 km/h (Ctrl-C to stop).")
    along = 0.0
    while True:
        position, heading = point_along(path, along)
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        bus = {"number": "Normal-1 · Sonadanga", "routeId": "r-sonadanga",
               "routeName": "KUET to Sonadanga", "driverId": "driver-demo",
               "lat": position[0], "lng": position[1], "updatedAt": "TS:" + now,
               "crowd": "unknown", "audience": "student", "fleetBusId": "normal-1",
               "heading": heading, "speed": SPEED}
        if crowded:
            bus.update({"crowd": "full", "crowdAt": "TS:" + now,
                        "reportLat": position[0], "reportLng": position[1]})
        put("buses/bus-normal-1", bus)
        along += SPEED * STEP
        if along > total:
            along = 0.0   # back to KUET and round again
        time.sleep(STEP)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "seed":
        seed()
    elif command == "drive":
        drive(crowded=len(sys.argv) > 2 and sys.argv[2] == "crowded")
    else:
        print("Usage: demo-bus.py seed | drive [crowded]")
