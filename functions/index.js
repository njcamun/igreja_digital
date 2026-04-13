const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

const normalizeTopic = (topic) => {
  if (!topic || typeof topic !== 'string') return 'global';
  return topic.replace(/[^a-zA-Z0-9_]/g, '_').toLowerCase();
};

const isUrgentAnnouncement = (announcement) => {
  if (!announcement) return false;
  return announcement.isUrgent === true || announcement.priority === 'urgente';
};

const buildPayload = ({ type, entityId, congregationId, title, body, route }) => ({
  notification: {
    title,
    body,
  },
  data: {
    type,
    entityId,
    congregationId: congregationId || '',
    title,
    body,
    route: route || '',
    createdAt: new Date().toISOString(),
  },
});

const validatePayloadInput = ({ title, body, topic }) => {
  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Título inválido.');
  }
  if (!body || typeof body !== 'string' || body.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Corpo inválido.');
  }
  if (topic != null && typeof topic !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Tópico inválido.');
  }
};

const sendNotificationToTopic = async (payload, topic) => {
  return admin.messaging().send({
    ...payload,
    topic: normalizeTopic(topic),
  });
};

const logNotification = async ({ eventId, type, entityId, topic, messageId, status, error }) => {
  await db.collection('notification_logs').doc(eventId).set(
    {
      eventId,
      type,
      entityId,
      topic,
      messageId: messageId || null,
      status,
      error: error || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
};

const hasBeenProcessed = async (eventId) => {
  const doc = await db.collection('notification_logs').doc(eventId).get();
  return doc.exists;
};

exports.sendUrgentAnnouncementNotification = functions.firestore
  .document('announcements/{announcementId}')
  .onCreate(async (snap, context) => {
    if (await hasBeenProcessed(context.eventId)) return null;

    const announcement = snap.data();
    if (!isUrgentAnnouncement(announcement)) return null;

    const payload = buildPayload({
      type: 'urgent_announcement',
      entityId: context.params.announcementId,
      congregationId: announcement.congregationId,
      title: 'Aviso Urgente',
      body: announcement.title,
      route: `/announcements/${context.params.announcementId}`,
    });

    const topic = announcement.isGlobal === true
      ? 'urgent_announcements'
      : (announcement.congregationId
        ? `congregation_${announcement.congregationId}`
        : 'global');

    try {
      const messageId = await sendNotificationToTopic(payload, topic);
      await logNotification({
        eventId: context.eventId,
        type: 'urgent_announcement',
        entityId: context.params.announcementId,
        topic,
        messageId,
        status: 'sent',
      });
      return messageId;
    } catch (error) {
      await logNotification({
        eventId: context.eventId,
        type: 'urgent_announcement',
        entityId: context.params.announcementId,
        topic,
        status: 'error',
        error: String(error),
      });
      throw error;
    }
  });

exports.sendNewSermonNotification = functions.firestore
  .document('sermons/{sermonId}')
  .onUpdate(async (change, context) => {
    if (await hasBeenProcessed(context.eventId)) return null;

    const newValue = change.after.data();
    const previousValue = change.before.data();
    if (!newValue || !previousValue) return null;

    if (newValue.isPublished === true && previousValue.isPublished !== true) {
      const payload = buildPayload({
        type: 'new_sermon',
        entityId: context.params.sermonId,
        congregationId: newValue.congregationId,
        title: 'Novo Sermão Disponível',
        body: newValue.title,
        route: `/sermons/${context.params.sermonId}`,
      });

      const topic = newValue.congregationId
        ? `congregation_${newValue.congregationId}`
        : 'global';

      try {
        const messageId = await sendNotificationToTopic(payload, topic);
        await logNotification({
          eventId: context.eventId,
          type: 'new_sermon',
          entityId: context.params.sermonId,
          topic,
          messageId,
          status: 'sent',
        });
        return messageId;
      } catch (error) {
        await logNotification({
          eventId: context.eventId,
          type: 'new_sermon',
          entityId: context.params.sermonId,
          topic,
          status: 'error',
          error: String(error),
        });
        throw error;
      }
    }
    return null;
  });

exports.sendPrayerRequestNotification = functions.firestore
  .document('prayer_requests/{prayerId}')
  .onCreate(async (snap, context) => {
    if (await hasBeenProcessed(context.eventId)) return null;

    const prayer = snap.data();
    if (!prayer) return null;

    const payload = buildPayload({
      type: 'prayer_request',
      entityId: context.params.prayerId,
      congregationId: prayer.congregationId,
      title: 'Novo Pedido de Oração',
      body: prayer.title || 'Um novo pedido de oração foi enviado.',
      route: `/prayers/${context.params.prayerId}`,
    });

    const topic = prayer.congregationId
      ? `congregation_${prayer.congregationId}`
      : 'global';

    try {
      const messageId = await sendNotificationToTopic(payload, topic);
      await logNotification({
        eventId: context.eventId,
        type: 'prayer_request',
        entityId: context.params.prayerId,
        topic,
        messageId,
        status: 'sent',
      });
      return messageId;
    } catch (error) {
      await logNotification({
        eventId: context.eventId,
        type: 'prayer_request',
        entityId: context.params.prayerId,
        topic,
        status: 'error',
        error: String(error),
      });
      throw error;
    }
  });

exports.sendEventNotification = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap, context) => {
    if (await hasBeenProcessed(context.eventId)) return null;

    const event = snap.data();
    if (!event) return null;

    const payload = buildPayload({
      type: 'future_event',
      entityId: context.params.eventId,
      congregationId: event.congregationId,
      title: 'Novo Evento',
      body: event.title || 'Um novo evento foi criado.',
      route: `/events/${context.params.eventId}`,
    });

    const topic = event.congregationId
      ? `congregation_${event.congregationId}`
      : 'global';

    try {
      const messageId = await sendNotificationToTopic(payload, topic);
      await logNotification({
        eventId: context.eventId,
        type: 'future_event',
        entityId: context.params.eventId,
        topic,
        messageId,
        status: 'sent',
      });
      return messageId;
    } catch (error) {
      await logNotification({
        eventId: context.eventId,
        type: 'future_event',
        entityId: context.params.eventId,
        topic,
        status: 'error',
        error: String(error),
      });
      throw error;
    }
  });

exports.sendNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const caller = callerDoc.data();
  if (!caller || caller.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Apenas administradores podem enviar notificações.');
  }

  const title = data.title;
  const body = data.body;
  const topic = data.topic || 'global';
  const notificationData = data.notificationData || {};
  validatePayloadInput({ title, body, topic });

  const payload = buildPayload({
    type: notificationData.type || 'generic',
    entityId: notificationData.entityId || '',
    congregationId: notificationData.congregationId,
    title,
    body,
    route: notificationData.route || '',
  });

  const eventId = `callable_${Date.now()}_${context.auth.uid}`;
  try {
    const messageId = await sendNotificationToTopic(payload, topic);
    await logNotification({
      eventId,
      type: notificationData.type || 'generic',
      entityId: notificationData.entityId || '',
      topic,
      messageId,
      status: 'sent',
    });
    return { messageId };
  } catch (error) {
    await logNotification({
      eventId,
      type: notificationData.type || 'generic',
      entityId: notificationData.entityId || '',
      topic,
      status: 'error',
      error: String(error),
    });
    throw error;
  }
});