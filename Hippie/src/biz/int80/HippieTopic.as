package biz.int80
{
	import flash.events.EventDispatcher;

	public class HippieTopic extends EventDispatcher
	{
		protected var type:String;
		protected var client:HippieClient;
		
		public function HippieTopic(hippieClient:HippieClient, topicName:String)
		{
			this.type = topicName;
			this.client = hippieClient;
		}
		
		public function get topicName():String {
			return type;
		}
		
		// be notified of events
		public function subscribe(eventCallback:Function):void {
			if (! this.type) {
				trace("trying to subscribe to topic with no name");
				return;
			}
			
			var req:HippieRequest = connect();
			req.addEventListener(HippieEvent.HIPPIE_EVENT, eventCallback);
		}
		
		// connect, don't subscribe
		// calls connectedCallback when successfully connected
		public function connect(connectedCallback:Function=null):HippieRequest {
			if (! this.type) {
				trace("trying to connect to topic with no name");
				return undefined;
			}
			
			var req:HippieRequest = this.client.newRequest("/mxhr/" + this.type);
			req.autoReconnect = true;
			req.connect(connectedCallback);
			
			return req;
		}
		
		public function publish(msg:Object=null):void {
			if (! msg) msg = {};
			
			// default event type to our topic name
			if (! msg.hasOwnProperty("type") || ! msg.type) msg.type = this.type;
			
			this.client.publish(msg);
		}
	}
}