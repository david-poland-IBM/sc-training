package swisscom.lab;

// -----( IS Java Code Template v1.2

import com.wm.data.*;
import com.wm.util.Values;
import com.wm.app.b2b.server.Service;
import com.wm.app.b2b.server.ServiceException;
// --- <<IS-START-IMPORTS>> ---
import java.net.InetAddress;
import java.time.Instant;
// --- <<IS-END-IMPORTS>> ---

public final class health

{
	// ---( internal utility methods )---

	final static health _instance = new health();

	static health _newInstance() { return new health(); }

	static health _cast(Object o) { return (health)o; }

	// ---( server methods )---




	public static final void info (IData pipeline)
        throws ServiceException
	{
		// --- <<IS-START(info)>> ---
		// @sigtype java 3.5
		// [o] field:0:required hostname
		// [o] field:0:required labEnvironment
		// [o] field:0:required version
		// [o] field:0:required javaVersion
		// [o] field:0:required maxHeapMB
		// [o] field:0:required timestamp
		//
		// Returns which container answered the request plus the LAB_ENVIRONMENT
		// and LAB_VERSION global variables, which are injected through
		// application.properties ($env{LAB_ENV}, $env{APP_VERSION}). Used in all
		// three labs to prove that configuration is externalized and to watch
		// load balancing and rolling updates.
		IDataCursor pc = pipeline.getCursor();
		try {
			String host;
			try {
				host = InetAddress.getLocalHost().getHostName();
			} catch (Exception e) {
				host = "unknown";
			}
			IDataUtil.put(pc, "hostname", host);
			IDataUtil.put(pc, "labEnvironment", globalVariable("LAB_ENVIRONMENT", "not-set"));
			IDataUtil.put(pc, "version", globalVariable("LAB_VERSION", "dev"));
			IDataUtil.put(pc, "javaVersion", System.getProperty("java.version"));
			IDataUtil.put(pc, "maxHeapMB", String.valueOf(Runtime.getRuntime().maxMemory() / (1024 * 1024)));
			IDataUtil.put(pc, "timestamp", Instant.now().toString());
		} finally {
			pc.destroy();
		}
		// --- <<IS-END>> ---


	}

	// --- <<IS-START-SHARED>> ---
	/**
	 * Reads an IS global variable through the public pub.globalVariable:getGlobalVariable
	 * service. Returns the fallback when the variable is not defined.
	 * Secure global variables (isSecure=true) only return a password-store handle,
	 * which is resolved through OutboundPasswordManager.
	 */
	static String globalVariable(String key, String fallback) {
		try {
			IData in = IDataFactory.create();
			IDataCursor c = in.getCursor();
			IDataUtil.put(c, "key", key);
			c.destroy();
			IData out = Service.doInvoke("pub.globalVariable", "getGlobalVariable", in);
			IDataCursor oc = out.getCursor();
			Object v = IDataUtil.get(oc, "value");
			Object secure = IDataUtil.get(oc, "isSecure");
			oc.destroy();
			if (v == null) return fallback;
			if ("true".equalsIgnoreCase(String.valueOf(secure))) {
				com.wm.util.security.WmSecureString s =
					com.wm.app.b2b.server.OutboundPasswordManager.retrievePassword(v.toString());
				return s == null ? fallback : new String(s.getChars());
			}
			return v.toString();
		} catch (Exception e) {
			return fallback;
		}
	}
	// --- <<IS-END-SHARED>> ---
}
