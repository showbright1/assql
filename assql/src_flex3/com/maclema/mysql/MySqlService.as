package com.maclema.mysql
{
	import com.maclema.mysql.events.MySqlErrorEvent;
	import com.maclema.mysql.events.MySqlEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.AsyncResponder;
	import mx.rpc.IResponder;
	
	/**
	 * Dispatched when an SQL error occurs.
	 **/
	[Event(name="sqlError", type="com.maclema.mysql.events.MySqlErrorEvent")]
	
	/**
	 * Dispatched when a data manipulation query successfully executes
	 **/
	[Event(name="response", type="com.maclema.mysql.events.MySqlEvent")]
	
	/**
	 * Dispatch when a query successfully executes
	 **/
	[Event(name="result", type="com.maclema.mysql.events.MySqlEvent")]
	
	/**
	 * Dispatch when successfully connected to MySql
	 **/
	[Event(name="connect", type="flash.events.Event")]
	
	/**
	 * Dispatched when the connection to MySql is terminated
	 **/
	[Event(name="close", type="flash.events.Event")]
	
	/**
	 * Use the &lt;assql:MySqlService&gt; tag to represent a MySqlService object in an MXML file. When you call the MySqlService object's
	 * send method, it makes a query to the currently connection MySql database.
	 * 
	 * @see com.maclema.mysql.mxml.MySqlService
	 **/
	public class MySqlService extends EventDispatcher
	{
		/**
		 * The hostname to connect to
		 **/
		public var hostname:String = "";
		
		/**
		 * The port to connect to
		 **/
		public var port:int = 3306;
		
		/**
		 * The username to authenticate with
		 **/
		public var username:String = "";
		
		/**
		 * The password to authenticate with
		 **/
		public var password:String = "";
		
		/**
		 * The database to switch to once connected
		 **/
		public var database:String = "";
		
		/**
		 * The character set to use for the connection
		 **/
		public var charSet:String = "utf-8";
		
		/**
		 * The responder to use for the mysql service
		 **/
		public var responder:IResponder;
		
		private var con:Connection;
		
		private var _lastResult:ArrayCollection;
		private var _lastResultSet:ResultSet;
		private var _connected:Boolean = false;
		
		private var _lastInsertID:int = -1;
		private var _lastAffectedRows:int = -1;
		
		/**
		 * Constructs a new MySqlService object.
		 */
		public function MySqlService()
		{
		}
		
		/**
		 * Returns the ArrayCollection of rows generated by ResultSet.getRows of the last ResultSet generated
		 * by calling send()
		 **/
		[Bindable("lastResultChanged")]
		public function get lastResult():ArrayCollection {
			return _lastResult;
		}
		
		/**
		 * Returns the last ResultSet object generated by calling send()
		 **/
		[Bindable("lastResultChanged")]
		public function get lastResultSet():ResultSet {
			return _lastResultSet;
		}
		
		/**
		 * Returns the last insert id returned after a data manipulation query by calling send()
		 **/
		[Bindable("lastResponseChanged")]
		public function get lastInsertID():int {
			return _lastInsertID;
		}
		
		/**
		 * Returns the number of affected rows returned after a data manipulation query by calling send()
		 **/
		[Bindable("lastResponseChanged")]
		public function get lastAffectedRows():int {
			return _lastAffectedRows;
		}
		
		/**
		 * Returns true or false indicating is the MySqlService is currently connected.
		 **/
		[Bindable("connectedChanged")]
		public function get connected():Boolean {
			return _connected;
		}
		
		/**
		 * Open the MySql connection
		 **/
		public function connect():void {
			disconnect();
			
			con = new Connection(hostname, port, username, password, database);
			con.addEventListener(Event.CONNECT, handleConnected);
			con.addEventListener(Event.CLOSE, handleDisconnected);
			con.addEventListener(MySqlErrorEvent.SQL_ERROR, handleConnectError);
			con.connect(charSet);
		}
		
		/**
		 * Closes the connection
		 **/
		public function disconnect():void {
			if ( con != null ) {
				con.disconnect();
				con.removeEventListener(Event.CONNECT, handleConnected);
				con.removeEventListener(Event.CLOSE, handleDisconnected);
				con.removeEventListener(MySqlErrorEvent.SQL_ERROR, handleConnectError);
				con = null;
			}
		}
		
		private function handleConnected(e:Event):void {
			_connected = true;
			dispatchEvent(new Event("connectedChanged"));
			dispatchEvent(e);
		}
		
		private function handleDisconnected(e:Event):void {
			_connected = false;
			dispatchEvent(new Event("connectedChanged"));
			dispatchEvent(e);
		}
		
		private function handleConnectError(e:MySqlErrorEvent):void {
			dispatchEvent(e);
		}
		
		/**
		 * Executes a query, you may pass in either an sql string or a Statement object.
		 **/
		public function send(queryObject:*):MySqlToken {
			var st:Statement;
			var token:MySqlToken;
			
			if ( queryObject is String ) {
				st = con.createStatement();
				token = st.executeQuery(String(queryObject));
				token.addResponder(new AsyncResponder(handleResult, handleError, token));
			}
			else if ( queryObject is Statement ) {
				st = Statement(queryObject);
				token = st.executeBinaryQuery(BinaryQuery(queryObject));
				token.addResponder(new AsyncResponder(handleResult, handleError, token));
			}
			
			return token;
		}
		
		private function handleResult(data:Object, token:Object=null):void {
			if ( data is ResultSet ) {
				_lastResultSet = ResultSet(data);
				_lastResult = _lastResultSet.getRows();
				dispatchEvent(new Event("lastResultChanged"));
			}
			else {
				_lastAffectedRows = data.affectedRows;
				_lastInsertID = data.insertID;
				dispatchEvent(new Event("lastResponseChanged"));
			}
			
			if ( responder != null ) {
				responder.result(data);
			}
		}
		
		private function handleError(info:Object):void {
			if ( responder != null ) {
				responder.fault(info);
			}
		}
	}
}