package i5.las2peer.services.mobsos.queryVisualization.database;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;

import i5.las2peer.execution.L2pThread;
import i5.las2peer.logging.NodeObserver.Event;
import i5.las2peer.p2p.Node;
import i5.las2peer.security.Agent;
import i5.las2peer.services.mobsos.queryVisualization.QueryVisualizationService;
import i5.las2peer.services.mobsos.queryVisualization.encoding.ModificationType;
import i5.las2peer.services.mobsos.queryVisualization.encoding.VisualizationType;

/**
 * SQLFilterManager.java <br>
 * This class manages custom created filters of a user.
 */
public class SQLFilterManager {

	private FilterMap userFilterMap = new FilterMap();
	private HashMap<StringPair, String> loadedFilterValues = new HashMap<StringPair, String>();

	private SQLDatabase storageDatabase;
	private boolean connected = false;

	private boolean connect() {
		try {
			storageDatabase.connect();
			connected = true;
		} catch (Exception e) {
			e.printStackTrace();
			return false;
		}
		return true;
	}

	private void disconnect(boolean wasConnected) {
		if (!wasConnected && connected) {
			storageDatabase.disconnect();
			connected = false;
		}
	}

	/*************** "service" helper methods *************************/

	/**
	 * get the current l2p thread
	 * 
	 * @return the L2pThread we're currently running in
	 */
	public final L2pThread getL2pThread() {
		Thread t = Thread.currentThread();

		if (!(t instanceof L2pThread))
			throw new IllegalStateException("Not executed in a L2pThread environment!");

		return (L2pThread) t;
	}

	/**
	 * get the currently active agent
	 * 
	 * @return active agent
	 */
	protected Agent getActiveAgent() {
		return getL2pThread().getContext().getMainAgent();
	}

	/**
	 * write a log message
	 * 
	 * @param message
	 *            Message that will be logged
	 */
	protected void logMessage(String message) {
		getActiveNode().observerNotice(Event.SERVICE_MESSAGE, this.getClass().getName() + ": " + message);
	}

	/**
	 * get the currently active l2p node (from the current thread context)
	 * 
	 * @return the currently active las2peer node
	 */
	protected Node getActiveNode() {
		return getL2pThread().getContext().getLocalNode();
	}

	/**************************
	 * end of service helper methods
	 ************************************/

	/**
	 * Constructor
	 * 
	 * @param storageDatabase
	 *            database for the storage
	 * @param user
	 *            User id
	 */
	public SQLFilterManager(SQLDatabase storageDatabase, long user) {
		this.storageDatabase = storageDatabase;
		if (user == 0) {
			// get the user's security object which contains the database
			// information
			user = getActiveAgent().getId();
		}

		SQLFilterSettings[] settings = null;

		boolean wasConnected = connected;
		try {
			connect();
			PreparedStatement p = storageDatabase.prepareStatement("SELECT * FROM FILTERS WHERE USER = ?;");
			p.setLong(1, user);
			ResultSet set = p.executeQuery();
			settings = SQLFilterSettings.fromResultSet(set);
		} catch (Exception e) {
			logMessage("Failed to get the users' SQL settings from the database! " + e.getMessage());
		} finally {
			disconnect(wasConnected);
		}

		if (settings == null || settings.length <= 0) {
			// there no database settings available yet...
		} else {
			for (SQLFilterSettings setting : settings)
				userFilterMap.put(setting.getKey(), setting);
		}

	}

	public SQLFilterManager(SQLDatabase storageDatabase) {
		this(storageDatabase, 0);
	}

	public boolean addFilter(String databaseKey, String filterName, String sqlQuery) throws Exception {
		StringPair filterKey = new StringPair(databaseKey, filterName);
		try {
			// TODO: sanity checks for the parameters
			if (filterExists(databaseKey, filterName)) {
				throw new Exception("Filter " + filterKey + " already exists!");
			}

			SQLFilterSettings filterSettings = new SQLFilterSettings(databaseKey, filterName, sqlQuery);
			boolean wasConnected = connected;
			connect();
			PreparedStatement p = storageDatabase.prepareStatement("INSERT INTO `FILTERS` (`KEY`, `QUERY`, `USER`, `DB_KEY`) VALUES (?,	?,	?,	?);");
			p.setString(1, filterName);
			p.setString(2, sqlQuery);
			p.setLong(3, getActiveAgent().getId());
			p.setString(4, databaseKey);
			p.executeUpdate();
			disconnect(wasConnected);
			userFilterMap.put(filterSettings.getKey(), filterSettings);

			return true;
		} catch (Exception e) {
			e.printStackTrace();
			logMessage(e.getMessage());
			throw e;
		}
	}

	public void databaseDeleted(String dbKey) {
		for (SQLFilterSettings f : userFilterMap.values()) {
			if (f.getDatabaseKey().equals(dbKey)) {
				try {
					deleteFilter(f.getDatabaseKey(), f.getName());
				} catch (Exception e) {
				}
			}
		}
	}

	public boolean deleteFilter(String dbKey, String filterName) throws Exception {
		StringPair filterKey = new StringPair(dbKey, filterName);
		try {
			if (!filterExists(dbKey, filterName)) {
				// throw new Exception("Filter with key " + filterKey + " does
				// not exists!");
				return false;
			}

			if (userFilterMap != null && userFilterMap.containsKey(filterKey)) {
				// delete from hash map
				boolean wasConnected = connected;
				connect();
				PreparedStatement s = storageDatabase.prepareStatement("DELETE FROM `FILTERS` WHERE `KEY` = ? AND `DB_KEY` = ? AND `USER` = ?");
				s.setString(1, filterName);
				s.setString(2, dbKey);
				s.setLong(3, getActiveAgent().getId());
				s.executeUpdate();
				disconnect(wasConnected);
				userFilterMap.remove(filterKey);
			}

			return true;
		} catch (Exception e) {
			e.printStackTrace();
			logMessage(e.getMessage());
			throw e;
		}
	}

	public boolean filterExists(String db, String key) {
		return filterExists(new StringPair(db, key));
	}

	public boolean filterExists(StringPair key) {
		try {
			return (userFilterMap.get(key) != null);
		} catch (Exception e) {
			e.printStackTrace();
			logMessage(e.getMessage());
		}
		return false;
	}

	public int getFilterCount() {
		return this.userFilterMap.size();
	}

	public List<StringPair> getFilterKeyList() {
		try {
			LinkedList<StringPair> keyList = new LinkedList<StringPair>();
			Iterator<StringPair> iterator = this.userFilterMap.keySet().iterator();
			while (iterator.hasNext()) {
				keyList.add(iterator.next());
			}

			return keyList;
		} catch (Exception e) {
			e.printStackTrace();
			logMessage(e.getMessage());
		}
		return null;
	}

	public SQLFilterSettings getFilter(String dbKey, String filterName) {
		StringPair filterKey = new StringPair(dbKey, filterName);
		SQLFilterSettings filterSettings = userFilterMap.get(filterKey);
		if (filterSettings == null) {
			return null;
		}
		return filterSettings;
	}

	public String getFilterValues(String dbKey, String filterName, VisualizationType visualizationTypeIndex, QueryVisualizationService agent) throws Exception {
		StringPair filterKey = new StringPair(dbKey, filterName);
		try {
			String filterValues = loadedFilterValues.get(new StringPair(dbKey, filterName + ":" + visualizationTypeIndex));

			if (filterValues == null) {
				// load them
				SQLFilterSettings filterSettings = userFilterMap.get(filterKey);

				if (filterSettings == null) {
					// the requested filter is not known/defined
					throw new DoesNotExistException("The requested filter is not known/configured! Requested:" + filterKey);
				}

				// get the filter values from the database...
				String query = filterSettings.getQuery();
				String databaseKey = filterSettings.getDatabaseKey();
				filterValues = agent.createQueryString(query, null, databaseKey, true, ModificationType.IDENTITIY.ordinal(), visualizationTypeIndex, null, false);

				// store/cache the filter values (note: the output format is
				// added in case the values for the same filter are requested
				// multiple times but in different output formats)
				loadedFilterValues.put(new StringPair(dbKey, filterName + ":" + visualizationTypeIndex), filterValues);
			}

			return filterValues;
		} catch (Exception e) {
			e.printStackTrace();
			logMessage(e.getMessage());
			throw e;
		}
	}
}
