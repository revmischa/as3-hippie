package biz.int80
{	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLRequest;
	
	import mx.collections.ArrayCollection;

	public class HippieClient extends EventDispatcher {		
		public var host:String;
		public var port:int;
		public var https:Boolean = false;
		public var path:String;
		public var clientId:String;
		protected var topics:Object = {};
		protected var requests:ArrayCollection = new ArrayCollection();

		public function HippieClient(hippieHost:String, hippiePort:int=80, basePath:String="/_hippie") {
			super();
			
			this.host = hippieHost;
			this.port = hippiePort;
			this.path = basePath;
		}
		
		protected function urlBase():String {
			return (https ? "https://" : "http://") + host + ":" + port + path;
		}
		
		public function newRequest(urlPath:String):HippieRequest {
			// create new request
			var url:URLRequest = new URLRequest(urlBase() + urlPath);
			var req:HippieRequest = new HippieRequest(url);
			this.requests.addItem(req);
			req.clientId = clientId;
			
			// set up callback
			var self:HippieClient = this;
			req.addEventListener(HippieEvent.HIPPIE_EVENT, function (evt:HippieEvent):void {
				// got a hippie message
				if (evt.channel && evt.channel == "hippie.pipe.set_client_id") {
					// got a client id
					clientId = evt.client_id;
				}
				
				self.dispatchEvent(evt);
			});
			
			return req;
		}
		
		public function disconnect():void {
			for each (var req:HippieRequest in this.requests) {
				if (req.connected)
					req.close();
			
				req = null;
			}
			
			this.requests.removeAll();
		}
		
		// return topic singleton
		public function topic(channel:String):HippieTopic {
			var topic:HippieTopic = this.topics[channel];
			if (topic) return topic;
			
			topic = new HippieTopic(this, channel);
			this.topics[channel] = topic;
			
			return topic;
		}
		
		// accepts HippieEvent or Object
		public function publish(msg:Object):void {
			var evt:HippieEvent = msg as HippieEvent;
			if (! evt) evt = new HippieEvent(msg);
			
			if (! evt.channel) {
				trace("Trying to publish event but no topic name is set");
				return;
			}
						
			var req:HippieRequest = this.newRequest("/pub/" + evt.channel);
			req.autoReconnect = false;
			req.url.method = "POST";
			req.setArgs(evt);
			req.connect();
		}
	}
}