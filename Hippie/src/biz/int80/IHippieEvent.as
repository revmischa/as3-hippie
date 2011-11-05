package biz.int80
{
	public interface IHippieEvent
	{
		function get message():Object;
		function get params():Object;
		function get channel():String;
	}
}