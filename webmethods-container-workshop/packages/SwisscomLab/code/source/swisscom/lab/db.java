package swisscom.lab;

// -----( IS Java Code Template v1.2

import com.wm.data.*;
import com.wm.util.Values;
import com.wm.app.b2b.server.Service;
import com.wm.app.b2b.server.ServiceException;
// --- <<IS-START-IMPORTS>> ---
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
// --- <<IS-END-IMPORTS>> ---

public final class db

{
	// ---( internal utility methods )---

	final static db _instance = new db();

	static db _newInstance() { return new db(); }

	static db _cast(Object o) { return (db)o; }

	// ---( server methods )---




	public static final void createOrder (IData pipeline)
        throws ServiceException
	{
		// --- <<IS-START(createOrder)>> ---
		// @sigtype java 3.5
		// [i] field:0:required customer
		// [i] field:0:required amount
		// [o] field:0:required orderId
		// [o] field:0:required servedBy
		IDataCursor pc = pipeline.getCursor();
		String customer = IDataUtil.getString(pc, "customer");
		String amount = IDataUtil.getString(pc, "amount");
		if (customer == null || customer.isEmpty()) customer = "Swisscom Lab";
		if (amount == null || amount.isEmpty()) amount = "100.00";
		try (Connection con = connect();
		     PreparedStatement ps = con.prepareStatement(
		         "INSERT INTO orders (customer, amount, created_by) VALUES (?, ?, ?) RETURNING id")) {
			ps.setString(1, customer);
			ps.setBigDecimal(2, new java.math.BigDecimal(amount));
			ps.setString(3, hostname());
			try (ResultSet rs = ps.executeQuery()) {
				rs.next();
				IDataUtil.put(pc, "orderId", String.valueOf(rs.getLong(1)));
			}
			IDataUtil.put(pc, "servedBy", hostname());
		} catch (Exception e) {
			throw new ServiceException("createOrder failed: " + e.getMessage());
		} finally {
			pc.destroy();
		}
		// --- <<IS-END>> ---


	}



	public static final void listOrders (IData pipeline)
        throws ServiceException
	{
		// --- <<IS-START(listOrders)>> ---
		// @sigtype java 3.5
		// [i] field:0:optional limit
		// [o] record:1:required orders
		// [o] - field:0:required id
		// [o] - field:0:required customer
		// [o] - field:0:required amount
		// [o] - field:0:required createdBy
		// [o] - field:0:required createdAt
		// [o] field:0:required count
		// [o] field:0:required servedBy
		IDataCursor pc = pipeline.getCursor();
		int limit = 10;
		try {
			String l = IDataUtil.getString(pc, "limit");
			if (l != null && !l.isEmpty()) limit = Integer.parseInt(l);
		} catch (NumberFormatException ignore) {
			// keep default
		}
		try (Connection con = connect();
		     PreparedStatement ps = con.prepareStatement(
		         "SELECT id, customer, amount, created_by, created_at FROM orders ORDER BY id DESC LIMIT ?")) {
			ps.setInt(1, limit);
			List<IData> rows = new ArrayList<>();
			try (ResultSet rs = ps.executeQuery()) {
				while (rs.next()) {
					IData row = IDataFactory.create();
					IDataCursor rc = row.getCursor();
					IDataUtil.put(rc, "id", String.valueOf(rs.getLong(1)));
					IDataUtil.put(rc, "customer", rs.getString(2));
					IDataUtil.put(rc, "amount", rs.getBigDecimal(3).toPlainString());
					IDataUtil.put(rc, "createdBy", rs.getString(4));
					IDataUtil.put(rc, "createdAt", String.valueOf(rs.getTimestamp(5)));
					rc.destroy();
					rows.add(row);
				}
			}
			IDataUtil.put(pc, "orders", rows.toArray(new IData[0]));
			IDataUtil.put(pc, "count", String.valueOf(rows.size()));
			IDataUtil.put(pc, "servedBy", hostname());
		} catch (Exception e) {
			throw new ServiceException("listOrders failed: " + e.getMessage());
		} finally {
			pc.destroy();
		}
		// --- <<IS-END>> ---


	}

	// --- <<IS-START-SHARED>> ---
	/**
	 * Opens a JDBC connection using values injected via application.properties:
	 *   globalvariable.LAB_DB_URL.value=$env{DB_URL}
	 *   globalvariable.LAB_DB_USER.value=$env{DB_USER}
	 *   globalvariable.LAB_DB_PASSWORD.value=$env{DB_PASSWORD}   (isSecure=true)
	 * The PostgreSQL driver jar is added to IntegrationServer/lib/jars/custom
	 * by the custom image's Containerfile.
	 */
	static Connection connect() throws Exception {
		String url = health.globalVariable("LAB_DB_URL", null);
		if (url == null) {
			throw new IllegalStateException("Global variable LAB_DB_URL is not set - check application.properties");
		}
		Class.forName("org.postgresql.Driver");
		Properties p = new Properties();
		p.setProperty("user", health.globalVariable("LAB_DB_USER", "wmuser"));
		p.setProperty("password", health.globalVariable("LAB_DB_PASSWORD", ""));
		p.setProperty("connectTimeout", "5");
		return DriverManager.getConnection(url, p);
	}

	static String hostname() {
		try {
			return java.net.InetAddress.getLocalHost().getHostName();
		} catch (Exception e) {
			return "unknown";
		}
	}
	// --- <<IS-END-SHARED>> ---
}
