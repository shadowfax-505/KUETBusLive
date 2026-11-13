//
//  rules.test.js
//  KUET Bus Live Firestore rules tests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Runs firestore.rules in the Firestore emulator and checks who may read and
//  write what. From the repository root:
//
//    firebase emulators:start --only firestore      (in one terminal)
//    npm --prefix firestore-tests test               (in another)
//
//  CI runs the same tests with firebase emulators:exec (see .github/workflows/build.yml).
//

const { test, before, beforeEach, after } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where } = require("firebase/firestore");

let env;

// People in the test database. Their profiles are written with the rules switched off.
const people = {
  admin: { name: "Admin", email: "admin@test.com", role: "admin", kuetId: "S-1", isApproved: true },
  student: { name: "Student", email: "student@test.com", role: "student", kuetId: "2207001", isApproved: true },
  teacher: { name: "Teacher", email: "teacher@test.com", role: "teacher", kuetId: "E-1", isApproved: true },
  newTeacher: { name: "New Teacher", email: "new@test.com", role: "teacher", kuetId: "E-2", isApproved: false },
  driver: { name: "Driver", email: "driver@test.com", role: "driver", kuetId: "D-1", isApproved: true },
  newDriver: { name: "New Driver", email: "newdriver@test.com", role: "driver", kuetId: "D-2", isApproved: false },
};

function db(uid) {
  if (!uid) return env.unauthenticatedContext().firestore();
  const email = people[uid] ? people[uid].email : `${uid}@test.com`;
  return env.authenticatedContext(uid, { email }).firestore();
}

function bus(driverId, extra = {}) {
  return {
    number: "Normal-1", routeId: "r1", routeName: "Rupsha", driverId,
    lat: 22.9, lng: 89.5, updatedAt: new Date(), crowd: "unknown", audience: "student",
    scheduleId: "s1", fleetBusId: "normal-1", ...extra,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-kuetbuslive-rules",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const store = context.firestore();
    for (const [uid, profile] of Object.entries(people)) {
      await setDoc(doc(store, "users", uid), profile);
    }
    await setDoc(doc(store, "buses", "student-bus"), bus("driver"));
    await setDoc(doc(store, "buses", "teacher-bus"), bus("driver", { audience: "teacher" }));
    await setDoc(doc(store, "routes", "r1"), { name: "Rupsha", stops: [] });
    // "driver" is the regular driver of Normal-1. Normal-2 has nobody.
    await setDoc(doc(store, "fleet", "normal-1"), { name: "Normal-1", defaultDriverId: "driver" });
    await setDoc(doc(store, "fleet", "normal-2"), { name: "Normal-2", defaultDriverId: null });
  });
});

after(async () => {
  await env.cleanup();
});

// ---------- Users ----------

test("signed-out people can read nothing", async () => {
  await assertFails(getDoc(doc(db(), "routes", "r1")));
  await assertFails(getDoc(doc(db(), "buses", "student-bus")));
});

test("you read your own profile, not someone else's", async () => {
  await assertSucceeds(getDoc(doc(db("student"), "users", "student")));
  await assertFails(getDoc(doc(db("student"), "users", "teacher")));
});

test("the admin reads every profile", async () => {
  await assertSucceeds(getDocs(collection(db("admin"), "users")));
  await assertFails(getDocs(collection(db("student"), "users")));
});

test("sign up as a student starts approved", async () => {
  await assertSucceeds(setDoc(doc(db("fresh"), "users", "fresh"),
    { name: "Fresh", email: "fresh@test.com", role: "student", kuetId: "2207002", isApproved: true }));
});

test("sign up cannot approve a teacher or driver, or make an admin", async () => {
  await assertFails(setDoc(doc(db("fresh"), "users", "fresh"),
    { name: "Fresh", email: "fresh@test.com", role: "teacher", kuetId: "E-9", isApproved: true }));
  await assertFails(setDoc(doc(db("fresh"), "users", "fresh"),
    { name: "Fresh", email: "fresh@test.com", role: "admin", kuetId: "S-9", isApproved: true }));
  await assertSucceeds(setDoc(doc(db("fresh"), "users", "fresh"),
    { name: "Fresh", email: "fresh@test.com", role: "driver", kuetId: "D-9", isApproved: false }));
});

test("sign up must use your own uid and your own email", async () => {
  await assertFails(setDoc(doc(db("fresh"), "users", "someoneElse"),
    { name: "Fresh", email: "fresh@test.com", role: "student", kuetId: "2207002", isApproved: true }));
  await assertFails(setDoc(doc(db("fresh"), "users", "fresh"),
    { name: "Fresh", email: "other@test.com", role: "student", kuetId: "2207002", isApproved: true }));
});

test("sign up cannot add unknown fields", async () => {
  await assertFails(setDoc(doc(db("fresh"), "users", "fresh"),
    { name: "Fresh", email: "fresh@test.com", role: "student", kuetId: "2207002", isApproved: true, isAdmin: true }));
});

test("you can change your stop and push token, not your role or approval", async () => {
  await assertSucceeds(updateDoc(doc(db("student"), "users", "student"),
    { favoriteStopName: "Rupsha", favoriteStopLat: 22.8, favoriteStopLng: 89.6, fcmToken: "abc" }));
  await assertFails(updateDoc(doc(db("student"), "users", "student"), { role: "admin" }));
  await assertFails(updateDoc(doc(db("newTeacher"), "users", "newTeacher"), { isApproved: true }));
  await assertFails(updateDoc(doc(db("student"), "users", "student"), { kuetId: "2207999" }));
  await assertFails(updateDoc(doc(db("student"), "users", "student"), { email: "x@test.com" }));
});

test("only the admin approves people or changes roles", async () => {
  await assertSucceeds(updateDoc(doc(db("admin"), "users", "newTeacher"), { isApproved: true }));
  await assertSucceeds(updateDoc(doc(db("admin"), "users", "newDriver"), { role: "driver", isApproved: true }));
});

test("you can delete your own profile, and the admin can delete anyone's", async () => {
  await assertSucceeds(deleteDoc(doc(db("student"), "users", "student")));
  await assertFails(deleteDoc(doc(db("teacher"), "users", "driver")));
  await assertSucceeds(deleteDoc(doc(db("admin"), "users", "teacher")));
});

// ---------- Timetable, routes and news ----------

test("everyone signed in reads routes, only the admin writes them", async () => {
  await assertSucceeds(getDoc(doc(db("student"), "routes", "r1")));
  await assertFails(setDoc(doc(db("student"), "routes", "r2"), { name: "x", stops: [] }));
  await assertFails(setDoc(doc(db("driver"), "schedules", "s2"), { tripName: "x" }));
  await assertSucceeds(setDoc(doc(db("admin"), "routes", "r2"), { name: "x", stops: [] }));
  await assertSucceeds(setDoc(doc(db("admin"), "schedules", "s2"), { tripName: "x" }));
});

test("only the admin posts announcements, and they need a title and body", async () => {
  const post = { title: "Holiday", body: "No buses on Friday", createdAt: new Date(), postedBy: "Admin" };
  await assertFails(setDoc(doc(db("student"), "announcements", "a1"), post));
  await assertFails(setDoc(doc(db("admin"), "announcements", "a1"), { ...post, title: "" }));
  await assertSucceeds(setDoc(doc(db("admin"), "announcements", "a1"), post));
});

// ---------- Buses ----------

test("an approved driver starts a trip as themselves", async () => {
  await assertSucceeds(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver")));
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("someoneElse")));
});

test("an unapproved driver or a student cannot start a trip", async () => {
  await assertFails(setDoc(doc(db("newDriver"), "buses", "bus-normal-1"), bus("newDriver")));
  await assertFails(setDoc(doc(db("student"), "buses", "bus-normal-1"), bus("student")));
});

test("a bus must have a position, a valid crowd level and no extra fields", async () => {
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { lat: "north" })));
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { crowd: "packed" })));
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { owner: "me" })));
});

test("the driver moves their own bus, nobody else's", async () => {
  await assertSucceeds(updateDoc(doc(db("driver"), "buses", "student-bus"), { lat: 22.91, lng: 89.51 }));
  await assertFails(updateDoc(doc(db("driver"), "buses", "student-bus"), { driverId: "someoneElse" }));
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", "driver2"),
      { name: "D2", email: "driver2@test.com", role: "driver", kuetId: "D-3", isApproved: true });
  });
  await assertFails(updateDoc(doc(db("driver2"), "buses", "student-bus"), { lat: 1 }));
});

test("a driver moving their bus can't change its route, trip or audience", async () => {
  await assertSucceeds(updateDoc(doc(db("driver"), "buses", "student-bus"), { lat: 22.92, lng: 89.52, heading: 90, speed: 8 }));
  await assertFails(updateDoc(doc(db("driver"), "buses", "student-bus"), { audience: "teacher" }));
  await assertFails(updateDoc(doc(db("driver"), "buses", "student-bus"), { routeId: "other-route" }));
  await assertFails(updateDoc(doc(db("driver"), "buses", "student-bus"), { scheduleId: "s9", lat: 22.93 }));
});

test("starting a trip again on a live bus is checked like a new trip", async () => {
  await assertSucceeds(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver")));
  await assertSucceeds(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { scheduleId: "s3" })));
  await addDriver("reserve");
  await setTripDrivers("normal-1", { s2: "reserve" });
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { scheduleId: "s2" })));
});

test("riders report the crowd only on buses they may ride", async () => {
  await assertSucceeds(updateDoc(doc(db("student"), "buses", "student-bus"), { crowd: "full" }));
  await assertFails(updateDoc(doc(db("student"), "buses", "teacher-bus"), { crowd: "full" }));
  await assertSucceeds(updateDoc(doc(db("teacher"), "buses", "teacher-bus"), { crowd: "seats" }));
});

test("crowd reports change only the crowd, to a known level", async () => {
  await assertFails(updateDoc(doc(db("student"), "buses", "student-bus"), { crowd: "packed" }));
  await assertFails(updateDoc(doc(db("student"), "buses", "student-bus"), { crowd: "full", lat: 0 }));
});

test("a teacher waiting for approval cannot report the crowd", async () => {
  await assertFails(updateDoc(doc(db("newTeacher"), "buses", "teacher-bus"), { crowd: "full" }));
});

test("ending a trip deletes the driver's own bus only", async () => {
  await assertFails(deleteDoc(doc(db("student"), "buses", "student-bus")));
  await assertSucceeds(deleteDoc(doc(db("driver"), "buses", "student-bus")));
  await assertSucceeds(deleteDoc(doc(db("admin"), "buses", "teacher-bus")));
});

// ---------- My places ----------

function place(extra = {}) {
  return { label: "Home", kind: "home", lat: 22.85, lng: 89.53, createdAt: new Date(), ...extra };
}

test("riders save up to five places of their own", async () => {
  await assertSucceeds(setDoc(doc(db("student"), "users", "student", "places", "p1"), place()));
  await assertSucceeds(setDoc(doc(db("student"), "users", "student", "places", "p5"), place({ kind: "tuition" })));
  await assertFails(setDoc(doc(db("student"), "users", "student", "places", "p6"), place()));
  await assertFails(setDoc(doc(db("student"), "users", "teacher", "places", "p1"), place()));
});

test("a place needs a short label, a known kind and a position", async () => {
  await assertFails(setDoc(doc(db("student"), "users", "student", "places", "p1"), place({ label: "" })));
  await assertFails(setDoc(doc(db("student"), "users", "student", "places", "p1"), place({ kind: "school" })));
  await assertFails(setDoc(doc(db("student"), "users", "student", "places", "p1"), place({ lat: "near" })));
  await assertFails(setDoc(doc(db("student"), "users", "student", "places", "p1"), place({ phone: "017" })));
});

test("nobody else reads your places", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", "student", "places", "p1"), place());
  });
  await assertSucceeds(getDoc(doc(db("student"), "users", "student", "places", "p1")));
  await assertFails(getDoc(doc(db("teacher"), "users", "student", "places", "p1")));
  await assertSucceeds(deleteDoc(doc(db("student"), "users", "student", "places", "p1")));
});

// ---------- Ride history ----------

function rideEvent(extra = {}) {
  return { id: "e1", kind: "followed", tripTitle: "Normal-2 · Rupsha", routeId: "r1",
           boardingKey: "place:p1", boardingName: "Home", dayType: "sunToThu", minuteOfDay: 490,
           date: new Date(), ...extra };
}

test("ride history is private to the rider and well formed", async () => {
  await assertSucceeds(setDoc(doc(db("student"), "users", "student", "rideHistory", "e1"), rideEvent()));
  await assertFails(setDoc(doc(db("teacher"), "users", "student", "rideHistory", "e2"), rideEvent()));
  await assertFails(setDoc(doc(db("student"), "users", "student", "rideHistory", "e3"), rideEvent({ kind: "spied" })));
  await assertFails(setDoc(doc(db("student"), "users", "student", "rideHistory", "e4"), rideEvent({ gps: [1, 2] })));
  await assertFails(getDoc(doc(db("teacher"), "users", "student", "rideHistory", "e1")));
  await assertSucceeds(deleteDoc(doc(db("student"), "users", "student", "rideHistory", "e1")));
});

// ---------- Waves ----------

function wave(uid, extra = {}) {
  const now = Date.now();
  return { uid, label: "Home", lat: 22.85, lng: 89.53, createdAt: new Date(now),
           expiresAt: new Date(now + 15 * 60 * 1000), ...extra };
}

test("a rider waves at a running bus they may ride", async () => {
  await assertSucceeds(setDoc(doc(db("student"), "buses", "student-bus", "waves", "student"), wave("student")));
  await assertFails(setDoc(doc(db("student"), "buses", "teacher-bus", "waves", "student"), wave("student")));
  await assertSucceeds(setDoc(doc(db("teacher"), "buses", "teacher-bus", "waves", "teacher"), wave("teacher")));
  await assertFails(setDoc(doc(db("student"), "buses", "no-such-bus", "waves", "student"), wave("student")));
});

test("one wave per rider per bus, in their own name, for at most 20 minutes", async () => {
  await assertFails(setDoc(doc(db("student"), "buses", "student-bus", "waves", "teacher"), wave("teacher")));
  await assertFails(setDoc(doc(db("student"), "buses", "student-bus", "waves", "student"), wave("teacher")));
  await assertFails(setDoc(doc(db("student"), "buses", "student-bus", "waves", "student"),
    wave("student", { expiresAt: new Date(Date.now() + 60 * 60 * 1000) })));
  await assertFails(setDoc(doc(db("student"), "buses", "student-bus", "waves", "student"),
    wave("student", { phone: "017" })));
});

test("drivers and unapproved teachers cannot wave", async () => {
  await assertFails(setDoc(doc(db("driver"), "buses", "student-bus", "waves", "driver"), wave("driver")));
  await assertFails(setDoc(doc(db("newTeacher"), "buses", "teacher-bus", "waves", "newTeacher"), wave("newTeacher")));
});

test("the bus's driver sees and clears waves; other riders can't see them", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "buses", "student-bus", "waves", "student"), wave("student"));
  });
  await assertSucceeds(getDocs(collection(db("driver"), "buses", "student-bus", "waves")));
  await assertFails(getDocs(collection(db("teacher"), "buses", "student-bus", "waves")));
  await assertSucceeds(getDoc(doc(db("student"), "buses", "student-bus", "waves", "student")));
  await assertFails(deleteDoc(doc(db("teacher"), "buses", "student-bus", "waves", "student")));
  await assertSucceeds(deleteDoc(doc(db("driver"), "buses", "student-bus", "waves", "student")));
});

test("a rider cancels their own wave", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "buses", "student-bus", "waves", "student"), wave("student"));
  });
  await assertSucceeds(deleteDoc(doc(db("student"), "buses", "student-bus", "waves", "student")));
});

// ---------- Bus assignment ----------

function day(offsetDays) {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return new Date(d.getTime() + offsetDays * 86400000);
}

async function setCover(busId, driverId, fromOffset, untilOffset) {
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), "fleet", busId), {
      cover: { driverId, fromDate: "x", untilDate: "y", start: day(fromOffset), end: day(untilOffset + 1),
               reason: "Sick", setBy: "admin" },
    });
  });
}

async function addDriver(uid, extra = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", uid),
      { name: uid, email: `${uid}@test.com`, role: "driver", kuetId: "D", isApproved: true, ...extra });
  });
}

test("only today's driver can start a trip on a fleet bus", async () => {
  await addDriver("reserve");
  await assertFails(setDoc(doc(db("reserve"), "buses", "bus-normal-1"), bus("reserve")));
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-2"), bus("driver", { fleetBusId: "normal-2" })));
  // The document ID must match the fleet bus, so one bus can't have two live trips.
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-other"), bus("driver")));
});

test("an active cover moves the bus to the cover driver", async () => {
  await addDriver("reserve");
  await setCover("normal-1", "reserve", 0, 2);
  await assertSucceeds(setDoc(doc(db("reserve"), "buses", "bus-normal-1"), bus("reserve")));
  await env.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), "buses", "bus-normal-1"));
  });
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver")));
});

test("a cover that ended or hasn't started leaves the regular driver in charge", async () => {
  await addDriver("reserve");
  await setCover("normal-1", "reserve", -5, -2);
  await assertSucceeds(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver")));
  await setCover("normal-1", "reserve", 1, 3);
  await assertFails(setDoc(doc(db("reserve"), "buses", "bus-normal-2"), bus("reserve", { fleetBusId: "normal-2" })));
});

test("a deactivated driver can't start or move a bus", async () => {
  await addDriver("driver", { active: false });
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver")));
  await assertFails(updateDoc(doc(db("driver"), "buses", "student-bus"), { lat: 1 }));
});

test("only the admin assigns drivers", async () => {
  await assertFails(updateDoc(doc(db("driver"), "fleet", "normal-2"), { defaultDriverId: "driver" }));
  await assertSucceeds(getDoc(doc(db("student"), "fleet", "normal-1")));
  await assertSucceeds(updateDoc(doc(db("admin"), "fleet", "normal-2"), { defaultDriverId: "driver" }));
});

async function setTripDrivers(busId, tripDrivers) {
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), "fleet", busId), { tripDrivers });
  });
}

test("a driver set for one trip drives that trip, and only that trip", async () => {
  await addDriver("reserve");
  await setTripDrivers("normal-1", { s2: "reserve" });
  // Trip s2 belongs to the trip driver, even over the regular driver.
  await assertSucceeds(setDoc(doc(db("reserve"), "buses", "bus-normal-1"), bus("reserve", { scheduleId: "s2" })));
  await env.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), "buses", "bus-normal-1"));
  });
  await assertFails(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { scheduleId: "s2" })));
  // Other trips of the bus stay with the regular driver.
  await assertFails(setDoc(doc(db("reserve"), "buses", "bus-normal-1"), bus("reserve", { scheduleId: "s1" })));
  await assertSucceeds(setDoc(doc(db("driver"), "buses", "bus-normal-1"), bus("driver", { scheduleId: "s1" })));
});

test("a trip driver wins over an active cover", async () => {
  await addDriver("reserve");
  await addDriver("cover");
  await setCover("normal-1", "cover", 0, 2);
  await setTripDrivers("normal-1", { s1: "reserve" });
  await assertFails(setDoc(doc(db("cover"), "buses", "bus-normal-1"), bus("cover")));
  await assertSucceeds(setDoc(doc(db("reserve"), "buses", "bus-normal-1"), bus("reserve")));
});

test("trip history follows trip drivers too", async () => {
  await addDriver("reserve");
  await setTripDrivers("normal-2", { s9: "reserve" });
  const trip = { driverId: "reserve", fleetBusId: "normal-2", scheduleId: "s9", routeId: "r1", startedAt: new Date() };
  await assertSucceeds(setDoc(doc(db("reserve"), "trips", "t1"), trip));
  await assertFails(setDoc(doc(db("reserve"), "trips", "t2"), { ...trip, scheduleId: "s1" }));
});

test("only the admin sets trip drivers, and only as a map", async () => {
  await assertFails(updateDoc(doc(db("driver"), "fleet", "normal-2"), { tripDrivers: { s1: "driver" } }));
  await assertSucceeds(updateDoc(doc(db("admin"), "fleet", "normal-2"), { tripDrivers: { s1: "driver" } }));
  await assertFails(updateDoc(doc(db("admin"), "fleet", "normal-2"), { tripDrivers: "driver" }));
  await assertSucceeds(updateDoc(doc(db("admin"), "fleet", "normal-2"), { tripDrivers: {} }));
});

function absence(driverId, extra = {}) {
  return { driverId, driverName: "D", fromDate: "2026-11-10", untilDate: "2026-11-12", reason: "Fever",
           status: "open", createdAt: new Date(), ...extra };
}

test("drivers send and read only their own \"I can't drive\" requests", async () => {
  await assertSucceeds(setDoc(doc(db("driver"), "driverAbsences", "a1"), absence("driver")));
  await assertFails(setDoc(doc(db("driver"), "driverAbsences", "a2"), absence("newDriver")));
  await assertFails(setDoc(doc(db("driver"), "driverAbsences", "a3"), absence("driver", { status: "covered" })));
  await assertFails(setDoc(doc(db("driver"), "driverAbsences", "a4"), absence("driver", { untilDate: "2026-11-01" })));
  await assertFails(setDoc(doc(db("student"), "driverAbsences", "a5"), absence("student")));
  await assertFails(getDoc(doc(db("newDriver"), "driverAbsences", "a1")));
  await assertSucceeds(getDoc(doc(db("admin"), "driverAbsences", "a1")));
  await assertFails(updateDoc(doc(db("driver"), "driverAbsences", "a1"), { status: "covered" }));
  await assertSucceeds(updateDoc(doc(db("admin"), "driverAbsences", "a1"), { status: "covered", coverDriverId: "x" }));
});

test("trip history records who drove, and only the end time changes later", async () => {
  const trip = { driverId: "driver", fleetBusId: "normal-1", scheduleId: "s1", routeId: "r1", startedAt: new Date() };
  await assertSucceeds(setDoc(doc(db("driver"), "trips", "t1"), trip));
  await assertFails(setDoc(doc(db("driver"), "trips", "t2"), { ...trip, fleetBusId: "normal-2" }));
  await assertSucceeds(updateDoc(doc(db("driver"), "trips", "t1"), { endedAt: new Date() }));
  await assertFails(updateDoc(doc(db("driver"), "trips", "t1"), { fleetBusId: "normal-2" }));
  await assertFails(getDoc(doc(db("student"), "trips", "t1")));
  await assertSucceeds(getDoc(doc(db("admin"), "trips", "t1")));
});

// ---------- Complaints ----------

function complaint(uid, role, extra = {}) {
  return {
    uid, userName: "Someone", userRole: role, category: "late", busName: "Normal-2",
    text: "The bus did not come at 7:10.", createdAt: new Date(), status: "open", readByAdmin: false, ...extra,
  };
}

async function seedComplaint(id, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "complaints", id), data);
  });
}

test("riders and drivers file complaints as themselves", async () => {
  await assertSucceeds(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "student")));
  await assertSucceeds(setDoc(doc(db("driver"), "complaints", "c2"), complaint("driver", "driver")));
  await assertFails(setDoc(doc(db("student"), "complaints", "c3"), complaint("teacher", "teacher")));
  await assertFails(setDoc(doc(db(), "complaints", "c4"), complaint("student", "student")));
});

test("a new complaint starts open and unread, with no reply", async () => {
  await assertFails(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "student", { status: "resolved" })));
  await assertFails(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "student", { adminReply: "done" })));
  await assertFails(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "student", { readByAdmin: true })));
  await assertFails(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "student", { category: "spam" })));
  await assertFails(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "admin")));
  await assertFails(setDoc(doc(db("student"), "complaints", "c1"), complaint("student", "student", { text: "" })));
});

test("you read only your own complaints, the admin reads all", async () => {
  await seedComplaint("c1", complaint("student", "student"));
  await assertSucceeds(getDoc(doc(db("student"), "complaints", "c1")));
  await assertFails(getDoc(doc(db("teacher"), "complaints", "c1")));
  await assertSucceeds(getDoc(doc(db("admin"), "complaints", "c1")));
  await assertSucceeds(getDocs(query(collection(db("student"), "complaints"), where("uid", "==", "student"))));
  await assertFails(getDocs(collection(db("student"), "complaints")));
  await assertSucceeds(getDocs(collection(db("admin"), "complaints")));
});

test("nobody edits a complaint after sending it", async () => {
  await seedComplaint("c1", complaint("student", "student"));
  await assertFails(updateDoc(doc(db("student"), "complaints", "c1"), { text: "changed" }));
  await assertFails(updateDoc(doc(db("student"), "complaints", "c1"), { status: "resolved" }));
});

test("the admin changes status and replies, but not the complaint itself", async () => {
  await seedComplaint("c1", complaint("student", "student"));
  await assertSucceeds(updateDoc(doc(db("admin"), "complaints", "c1"),
    { status: "inReview", adminReply: "We are checking.", repliedAt: new Date(), readByAdmin: true }));
  await assertFails(updateDoc(doc(db("admin"), "complaints", "c1"), { text: "rewritten" }));
  await assertFails(updateDoc(doc(db("admin"), "complaints", "c1"), { status: "closed" }));
});

test("you can delete your own complaints (account deletion)", async () => {
  await seedComplaint("c1", complaint("student", "student"));
  await seedComplaint("c2", complaint("teacher", "teacher"));
  await assertFails(deleteDoc(doc(db("student"), "complaints", "c2")));
  await assertSucceeds(deleteDoc(doc(db("student"), "complaints", "c1")));
});

// ---------- Everything else ----------

test("unknown collections are closed", async () => {
  await assertFails(setDoc(doc(db("admin"), "secrets", "x"), { a: 1 }));
  await assertFails(getDoc(doc(db("admin"), "secrets", "x")));
});
