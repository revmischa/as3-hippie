package biz.int80
{
	import flash.events.Event;
	
	[Bindable] public class HippieEvent extends Event implements IHippieEvent
	{
		public static const HIPPIE_EVENT:String = "hippieEvent";
		
		// actually holds event params
		private var message:Object;
		
		public function HippieEvent(args:Object, bubbles:Boolean=false) {
			message = args;
			super(HIPPIE_EVENT, bubbles);
		}
		
		public function get args():Object {
			return message;
		}
		
		public function get channel():String {
			return this.message.type;
		}
	}
}