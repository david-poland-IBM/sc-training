package swisscom.lab;

// -----( IS Java Code Template v1.2

import com.wm.data.*;
import com.wm.util.Values;
import com.wm.app.b2b.server.Service;
import com.wm.app.b2b.server.ServiceException;
// --- <<IS-START-IMPORTS>> ---
import java.lang.reflect.Method;
// --- <<IS-END-IMPORTS>> ---

public final class jms

{
	// ---( internal utility methods )---

	final static jms _instance = new jms();

	static jms _newInstance() { return new jms(); }

	static jms _cast(Object o) { return (jms)o; }

	// ---( server methods )---




	public static final void receiveOrder (IData pipeline)
        throws ServiceException
	{
		// --- <<IS-START(receiveOrder)>> ---
		// @sigtype java 3.5
		// [i] field:0:optional timeoutMs
		// [o] field:0:required received
		// [o] field:0:required body
		// [o] field:0:required servedBy
		IDataCursor pc = pipeline.getCursor();
		long timeout = 5000L;
		try {
			String t = IDataUtil.getString(pc, "timeoutMs");
			if (t != null && !t.isEmpty()) timeout = Long.parseLong(t);
		} catch (NumberFormatException ignore) {
			// keep default
		}
		Object consumer = null;
		try {
			IData cin = IDataFactory.create();
			IDataCursor cc = cin.getCursor();
			IDataUtil.put(cc, "connectionAliasName", alias());
			IDataUtil.put(cc, "destinationName", queue());
			IDataUtil.put(cc, "destinationType", "QUEUE");
			cc.destroy();
			IData cout = Service.doInvoke("pub.jms", "createConsumer", cin);
			IDataCursor coc = cout.getCursor();
			consumer = IDataUtil.get(coc, "consumer");
			coc.destroy();

			IData rin = IDataFactory.create();
			IDataCursor rc = rin.getCursor();
			IDataUtil.put(rc, "consumer", consumer);
			IDataUtil.put(rc, "timeout", Long.valueOf(timeout));
			rc.destroy();
			IData rout = Service.doInvoke("pub.jms", "receive", rin);
			IDataCursor roc = rout.getCursor();
			IData msg = IDataUtil.getIData(roc, "JMSMessage");
			roc.destroy();

			String body = null;
			if (msg != null) {
				IDataCursor mc = msg.getCursor();
				IData b = IDataUtil.getIData(mc, "body");
				mc.destroy();
				if (b != null) {
					IDataCursor bc = b.getCursor();
					body = IDataUtil.getString(bc, "string");
					bc.destroy();
				}
			}
			IDataUtil.put(pc, "received", String.valueOf(msg != null));
			IDataUtil.put(pc, "body", body == null ? "" : body);
			IDataUtil.put(pc, "servedBy", db.hostname());
		} catch (Exception e) {
			throw new ServiceException("receiveOrder failed: " + e.getMessage());
		} finally {
			closeQuietly(consumer);
			pc.destroy();
		}
		// --- <<IS-END>> ---


	}



	public static final void sendOrder (IData pipeline)
        throws ServiceException
	{
		// --- <<IS-START(sendOrder)>> ---
		// @sigtype java 3.5
		// [i] field:0:optional message
		// [o] field:0:required sent
		// [o] field:0:required destination
		// [o] field:0:required JMSMessageID
		// [o] field:0:required servedBy
		IDataCursor pc = pipeline.getCursor();
		String text = IDataUtil.getString(pc, "message");
		if (text == null || text.isEmpty()) {
			text = "{\"order\":\"lab\",\"from\":\"" + db.hostname() + "\",\"at\":\"" + java.time.Instant.now() + "\"}";
		}
		try {
			IData body = IDataFactory.create();
			IDataCursor bc = body.getCursor();
			IDataUtil.put(bc, "string", text);
			bc.destroy();
			IData msg = IDataFactory.create();
			IDataCursor mc = msg.getCursor();
			IDataUtil.put(mc, "body", body);
			mc.destroy();

			IData in = IDataFactory.create();
			IDataCursor ic = in.getCursor();
			IDataUtil.put(ic, "connectionAliasName", alias());
			IDataUtil.put(ic, "destinationName", queue());
			IDataUtil.put(ic, "destinationType", "QUEUE");
			IDataUtil.put(ic, "JMSMessage", msg);
			ic.destroy();
			IData out = Service.doInvoke("pub.jms", "send", in);

			String id = "";
			IDataCursor oc = out.getCursor();
			IData om = IDataUtil.getIData(oc, "JMSMessage");
			oc.destroy();
			if (om != null) {
				IDataCursor omc = om.getCursor();
				IData h = IDataUtil.getIData(omc, "header");
				omc.destroy();
				if (h != null) {
					IDataCursor hc = h.getCursor();
					Object v = IDataUtil.get(hc, "JMSMessageID");
					hc.destroy();
					if (v != null) id = v.toString();
				}
			}
			IDataUtil.put(pc, "sent", "true");
			IDataUtil.put(pc, "destination", queue());
			IDataUtil.put(pc, "JMSMessageID", id);
			IDataUtil.put(pc, "servedBy", db.hostname());
		} catch (Exception e) {
			throw new ServiceException("sendOrder failed: " + e.getMessage());
		} finally {
			pc.destroy();
		}
		// --- <<IS-END>> ---


	}

	// --- <<IS-START-SHARED>> ---
	/** JMS connection alias name - defined in application.properties (jms.LAB_UM_JMS.*). */
	static String alias() {
		return health.globalVariable("LAB_JMS_ALIAS", "LAB_UM_JMS");
	}

	/** Queue name - created on demand in UM by the JMS alias (automaticallyCreateUMAdminObjects). */
	static String queue() {
		return health.globalVariable("LAB_JMS_QUEUE", "LabOrders");
	}

	static void closeQuietly(Object consumer) {
		if (consumer == null) return;
		try {
			Method m = consumer.getClass().getMethod("close");
			m.invoke(consumer);
		} catch (Exception ignore) {
			// best effort
		}
	}
	// --- <<IS-END-SHARED>> ---
}
