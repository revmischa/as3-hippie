package biz.int80
{
	import flash.events.EventDispatcher;

	public class HippieTopic extends EventDispatcher
	{
		protected var channel:String;
		protected var client:HippieClient;
		
		public function HippieTopic(hippieClient:HippieClient, topicName:String)
		{
			this.channel = topicName;
			this.client = hippieClient;
		}
		
		// be notified of events
		public function subscribe(cb:Function):void {
			if (! this.channel) {
				trace("trying to subscribe to topic with no name");
				return;
			}
			
			var req:HippieRequest = this.client.newRequest("/mxhr/" + this.channel);
			req.autoReconnect = true;
			req.addEventListener(HippieEvent.HIPPIE_EVENT, cb);
			req.connect();
		}
		
		public function publish(msg:Object=null):void {
			if (! msg) msg = {};
			if (! msg.name) msg.type = this.channel;
			this.client.publish(msg);
		}
	}
}