package biz.int80
{
	import com.adobe.serialization.json.JSON;
	
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.net.URLVariables;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;

	[Bindable] public class HippieRequest extends URLStream
	{
		// save currently received but unparsed data
		protected var buf:String = '';
		
		public var url:URLRequest;
		public var clientId:String;
		public var autoReconnect:Boolean = false;
		protected var callback:Function;
		protected var boundary:String;
		protected var connectRetries:int = 0;
		
		public function HippieRequest(url:URLRequest) {
			super();
			
			this.url = url;
			
			this.addEventListener(HTTPStatusEvent.HTTP_STATUS, gotStatus);
			if (HTTPStatusEvent.HTTP_RESPONSE_STATUS) 
				this.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, gotStatus);
			this.addEventListener(ProgressEvent.PROGRESS, gotData);
			this.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
		
		protected function reset():void {
			this.boundary = null;
		}
		
		public function setArgs(evt:HippieEvent):void {
			if (! url.data) url.data = new URLVariables();
			
			// copy args
			url.data.message = com.adobe.serialization.json.JSON.encode(evt.message);
		}
		
		public function connect(cb:Function=null):void {
			this.reset();
			this.callback = cb;
			
			var self:HippieRequest = this;
			
			var finishedCallback:Function = function (evt:Event):void {
				trace("request complete");
				//connectRetries = 0;

				if (cb != null) cb();
				self.removeEventListener(Event.COMPLETE, finishedCallback);
				
				if (autoReconnect)
					self.reconnect(cb);
			};
			
			// add client_id to request
			if (! this.url.data) this.url.data = new URLVariables();
			if (this.clientId && ! this.url.data.client_id) this.url.data.client_id = clientId;
			
			this.addEventListener(Event.COMPLETE, finishedCallback);
			super.load(this.url);
		}
		
		private var reconnectTimer:int;
		public function reconnect(cb:Function=null):void {
			if (this.connected)
    			this.close();
			
			// reconnect with exponential backoff
			var delay:int = 1000 * connectRetries*connectRetries;
			// max delay 10 mins
			var maxRetryDelay:uint = 1000 * 60 * 60 * 10;
			if (delay > maxRetryDelay)
				delay = maxRetryDelay;
			
			var self:HippieRequest = this;
			
			if (reconnectTimer) clearTimeout(reconnectTimer);
			reconnectTimer = setTimeout(function ():void {
				if (self.connected) return;
				
				trace("reconnecting...");
				
				self.connectRetries++;
				self.connect(cb);
			}, delay);
			trace("reconnecting in " + (delay/1000) + "s...");
		}
		
		protected function gotStatus(evt:HTTPStatusEvent):void {
			if (evt.status == 200) {
				// this request is finished
				// ...
			}
			
			// get boundary from content-type header, if available
			if (evt.hasOwnProperty("responseHeaders") && evt.responseHeaders) {
				var ct_idx:int = evt.responseHeaders.indexOf('Content-Type');
				if (ct_idx != -1) {
					var contentType:String = evt.responseHeaders[ct_idx];
					if (contentType) {
						var m:Array = contentType.match(/boundary="(\w+)"/);
						if (m && m.length)
							boundary = '--' + m[0];
						
						trace("got boundary from headers: " + boundary);
					}
				}
			}
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void {
			trace("IO Error on hippie client: " + event);
			if (autoReconnect)
    			this.reconnect();
		}
		
		protected function gotData(evt:ProgressEvent):void {
			
			var str:String = readUTFBytes(bytesAvailable);
			//trace("data: " + str);
			buf += str;
			
			// do we have a boudary yet? if not, we probably don't have access to headers and need to assume a boundary
			if (! boundary && buf.indexOf("\n") != -1) {
				// boundary should be first line
				var m:Array = buf.match(/^--(\w+)\r?\n/ms);
				if (!m || ! m.length) {
					// we expected the boundary to be the first line. it's not, so we got an invalid response
					trace("Failed to parse hippie reponse: " + buf);
					return;
				}
				
				boundary = m[0];
				
				// trim whitespace
				boundary = boundary.replace(/\s+$/m, '');
			}
			
			this.parseParts();
			
			// FIXME: _assume_ that each boundary is complete and that we have 
		}
		
		// split buffer on boundary, process parts
		protected function parseParts():void {
			if (! boundary) return;
			
			// at this point we can assume we're good, connection-wise
			connectRetries = 0;
			
			var parts:Array = buf.split(boundary);
			
			// if last part is empty, that means we have a boundary on the final response.
			// this means we have a complete set of parts, and we can clear our buffer
			if (parts.length) {
				var finalPart:String = parts.pop();
				finalPart = finalPart.replace(/\s+$/m, '');
				if (! finalPart) {
					// final part is empty, means we're done reading everything in buf
					buf = "";
				} else {
					trace("Incomplete final part: " + finalPart);
					buf = finalPart;
				}
			}
			
			for each (var part:String in parts) {
				if (part)
    				this.parsePart(part);
			}
		}
		
		// parse a part, headers + body
		protected function parsePart(part:String):void {
			// first, parse part headers. should be just content-type
			var headers:Array = [];
			var headerText:String;
			var bodyText:String;
						
			// find end of headers
			var headerEndIdx:int = part.indexOf("\n\n");
			if (headerEndIdx == -1) {
				// failed to split headers/body
				trace("Failed to parse headers for part: '" + part + "'");
				return;
			}
			
			headerText = part.substr(0, headerEndIdx);
			bodyText = part.substr(headerEndIdx + 2);
			
			if (bodyText) {
				this.parseMessage(bodyText);
			} else {
				trace("Got empty part, headers: " + headers);
			}
		}
		
		// got event JSON
		protected function parseMessage(json:String):void {
			var msg:Object = com.adobe.serialization.json.JSON.decode(json);
			if (! msg) return;
			
			this.processMessage(msg);
		}
		
		// decoded event object
		protected function processMessage(msg:Object):void {
			// create HippieEvent
			var evt:HippieEvent = new HippieEvent(msg, true);
			//trace('got hippie event: ' + msg.type);
			this.dispatchEvent(evt);
		}
	}
}