//
//  index.js
//  KUET Bus Live Cloud Functions
//
//  Created by Muttakin Rahman Shoscho.
//
//  When a driver starts a trip, the app creates a document in "buses".
//  This function runs on the server at that moment and sends a push
//  notification to everyone subscribed to that route's topic, for example
//  "Normal-2 · Rupsha just left campus".
//
//  Deploy with:  firebase deploy --only functions   (needs the Blaze plan)
//

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();

exports.notifyTripStarted = onDocumentCreated("buses/{busId}", async (event) => {
  const bus = event.data && event.data.data();
  if (!bus || !bus.routeId) {
    logger.warn("New bus without a route, nothing to send", event.params.busId);
    return;
  }

  // Must match PushManager.topic(forRouteId:) in the app.
  const topic = `route-${bus.routeId}`;

  const message = {
    topic: topic,
    notification: {
      title: `${bus.number} just left campus`,
      body: `On ${bus.routeName}. Open KUET Bus Live to see it on the map.`,
    },
    apns: {
      payload: { aps: { sound: "default" } },
    },
  };

  try {
    const id = await getMessaging().send(message);
    logger.info(`Sent "${message.notification.title}" to ${topic}`, id);
  } catch (error) {
    logger.error(`Could not send to ${topic}`, error);
  }
});
