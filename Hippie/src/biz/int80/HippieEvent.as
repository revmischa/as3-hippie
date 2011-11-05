package biz.int80
{
	import flash.events.Event;
	
	[Bindable] public class HippieEvent extends Event implements IHippieEvent
	{
		public static const HIPPIE_EVENT:String = "hippieEvent";
		
		// actually holds event params
		private var _message:Object;
		
		public function HippieEvent(fromMessage:Object, bubbles:Boolean=false) {
			_message = fromMessage;
			if (! _message.params)
				_message.params = {};
			super(HIPPIE_EVENT, bubbles);
		}
		
		public function get message():Object {
			return _message;
		}
		
		public function get params():Object {
			return _message.params;
		}
		
		public function get client_id():String {
			return _message.client_id;
		}
		
		public function get channel():String {
			return this._message.type;
		}
	}
}