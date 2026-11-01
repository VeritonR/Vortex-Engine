package backend;

#if sys
import sys.net.Address;
import sys.net.Host;
import sys.net.UdpSocket;
#end

/**
 * Opens the online port on the router by itself (UPnP), so the other player can join with the host's IP without Radmin or
 * opening the port by hand. It finds the router, asks for its address on the internet and for the port to be sent to this PC.
 *
 * It doesn't work when the router has UPnP off, or when the internet provider shares one address between many clients
 * (CGNAT: the router's own address is then 100.64.x.x or a private one): `result` says which, for the lobby to tell the player
 * to use Radmin (or another VPN) instead.
 *
 * Everything here waits on the network: call it from a thread of its own.
 */
class Upnp
{
	public static inline var SEARCHING:String = 'searching';
	public static inline var OPEN:String = 'open';
	public static inline var CGNAT:String = 'cgnat';
	public static inline var NO_ROUTER:String = 'no_router';
	public static inline var FAILED:String = 'failed';

	/**
	 * What happened the last time: null before trying, then one of the constants above.
	 */
	public static var result(default, null):String = null;

	/**
	 * The router's address on the internet, the one the other player joins with (only when `result` is OPEN).
	 */
	public static var externalIp(default, null):String = null;

	// The router's service the port was opened on, to close it again
	static var controlUrl:String = null;
	static var serviceType:String = null;
	static var openedPort:Int = -1;

	static inline var SEARCH_TARGET:String = 'urn:schemas-upnp-org:device:InternetGatewayDevice:1';

	/**
	 * Opens `port` (TCP) on the router to this PC. Waits up to a few seconds for the router.
	 */
	public static function openPort(port:Int, description:String = 'Vortex Engine online'):String
	{
		result = SEARCHING;
		externalIp = null;
		#if sys
		try
		{
			var found = findService();
			if(found == null)
			{
				result = NO_ROUTER;
				return result;
			}
			controlUrl = found.control;
			serviceType = found.service;

			var address:String = callAction('GetExternalIPAddress', '', 'NewExternalIPAddress');
			if(address == null || isSharedAddress(address))
			{
				// (the port could be opened on this router, but the provider's one in front of it would still not let anyone in)
				result = CGNAT;
				return result;
			}

			var local:String = localAddressTowards(found.router);
			if(local == null)
			{
				result = FAILED;
				return result;
			}

			// a lease of an hour first (the mapping goes away by itself if the game closes without taking it out),
			// some routers only take permanent ones
			var mapped:Bool = false;
			for (lease in [3600, 0])
			{
				var args:String = '<NewRemoteHost></NewRemoteHost><NewExternalPort>$port</NewExternalPort><NewProtocol>TCP</NewProtocol>'
					+ '<NewInternalPort>$port</NewInternalPort><NewInternalClient>$local</NewInternalClient><NewEnabled>1</NewEnabled>'
					+ '<NewPortMappingDescription>$description</NewPortMappingDescription><NewLeaseDuration>$lease</NewLeaseDuration>';
				if(callAction('AddPortMapping', args, null) != null)
				{
					mapped = true;
					break;
				}
			}
			if(!mapped)
			{
				result = FAILED;
				return result;
			}

			openedPort = port;
			externalIp = address;
			result = OPEN;
		}
		catch(e:Dynamic)
		{
			trace('UPnP: $e');
			result = FAILED;
		}
		#else
		result = FAILED;
		#end
		return result;
	}

	/**
	 * Takes out the port opened by `openPort()`, if it was.
	 */
	public static function closePort():Void
	{
		#if sys
		if(openedPort < 0 || controlUrl == null) return;
		var port:Int = openedPort;
		openedPort = -1;
		result = null;
		externalIp = null;
		try
		{
			callAction('DeletePortMapping', '<NewRemoteHost></NewRemoteHost><NewExternalPort>$port</NewExternalPort><NewProtocol>TCP</NewProtocol>', null);
		}
		catch(e:Dynamic) {}
		#end
	}

	/**
	 * If an address is one a provider shares between clients (CGNAT, 100.64.0.0/10) or one of a local network (another router
	 * in front of this one): nobody on the internet can reach it.
	 */
	public static function isSharedAddress(address:String):Bool
	{
		var parts:Array<String> = address.split('.');
		if(parts.length != 4) return true;
		var a:Null<Int> = Std.parseInt(parts[0]);
		var b:Null<Int> = Std.parseInt(parts[1]);
		if(a == null || b == null) return true;
		return a == 0 || a == 10 || a == 127 || (a == 100 && b >= 64 && b <= 127) || (a == 172 && b >= 16 && b <= 31)
			|| (a == 192 && b == 168) || (a == 169 && b == 254);
	}

	/**
	 * The address shown hidden but its end, for the lobby (people stream the game): "***.***.***.89".
	 */
	public static function maskedAddress(address:String):String
	{
		if(address == null) return '';
		var parts:Array<String> = address.split('.');
		if(parts.length != 4) return '***';
		return '***.***.***.' + parts[3];
	}

	#if sys
	// The router's WAN service: asked for on the network (SSDP), its description read for where its service is
	static function findService():{router:String, control:String, service:String}
	{
		for (location in searchRouters())
		{
			var xml:String = httpGet(location);
			if(xml == null) continue;

			for (kind in ['WANIPConnection', 'WANPPPConnection'])
			{
				var service:EReg = new EReg('<serviceType>(urn:schemas-upnp-org:service:$kind:\\d)</serviceType>[\\s\\S]*?<controlURL>([^<]+)</controlURL>', '');
				if(!service.match(xml)) continue;

				var base:String = location;
				var urlBase:EReg = ~/<URLBase>([^<]+)<\/URLBase>/;
				if(urlBase.match(xml)) base = urlBase.matched(1);
				return {router: hostOf(location), control: resolveUrl(base, StringTools.trim(service.matched(2))), service: service.matched(1)};
			}
		}
		return null;
	}

	// The description addresses of the routers that answer. The question goes to everyone (multicast) and straight to the routers
	// this PC probably has: Windows' firewall lets an answer through only from where the question went, so the multicast one's
	// answers are usually dropped
	static function searchRouters():Array<String>
	{
		var found:Array<String> = [];
		var udp:UdpSocket = new UdpSocket();
		try
		{
			var message:haxe.io.Bytes = haxe.io.Bytes.ofString('M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\n'
				+ 'ST: $SEARCH_TARGET\r\n\r\n');
			var targets:Array<String> = ['239.255.255.250'];
			for (candidate in gatewayCandidates())
				if(!targets.contains(candidate)) targets.push(candidate);

			for (target in targets)
			{
				var address:Address = new Address();
				address.host = new Host(target).ip;
				address.port = 1900;
				try udp.sendTo(message, 0, message.length, address) catch(e:Dynamic) {}
			}

			udp.setTimeout(0.25);
			var buffer:haxe.io.Bytes = haxe.io.Bytes.alloc(4096);
			var from:Address = new Address();
			var until:Float = haxe.Timer.stamp() + 3;
			var location:EReg = ~/location:\s*(\S+)/i;
			while(haxe.Timer.stamp() < until)
			{
				var length:Int = 0;
				try length = udp.readFrom(buffer, 0, buffer.length, from) catch(e:Dynamic) { continue; }
				if(length <= 0) continue;
				if(location.match(buffer.getString(0, length)))
				{
					var url:String = location.matched(1);
					if(!found.contains(url)) found.push(url);
					// (the router answered: no need to wait for the rest)
					if(found.length > 0 && haxe.Timer.stamp() < until - 2.5) until = haxe.Timer.stamp() + 0.5;
				}
			}
		}
		catch(e:Dynamic) {}
		try udp.close() catch(e:Dynamic) {}
		return found;
	}

	// Where the router probably is: the first and last address of this PC's network, and the usual ones
	static function gatewayCandidates():Array<String>
	{
		var list:Array<String> = [];
		var local:String = localAddressTowards('8.8.8.8'); //(no packet is sent: it's only which network the internet goes through)
		if(local != null)
		{
			var parts:Array<String> = local.split('.');
			if(parts.length == 4)
			{
				list.push('${parts[0]}.${parts[1]}.${parts[2]}.1');
				list.push('${parts[0]}.${parts[1]}.${parts[2]}.254');
			}
		}
		for (common in ['192.168.0.1', '192.168.1.1', '192.168.15.1', '192.168.100.1', '10.0.0.1'])
			if(!list.contains(common)) list.push(common);
		return list;
	}

	// This PC's address on the network that leads to `target`
	static function localAddressTowards(target:String):String
	{
		var udp:UdpSocket = new UdpSocket();
		var local:String = null;
		try
		{
			udp.connect(new Host(target), 1900);
			var mine = udp.host();
			if(mine != null && mine.host != null) local = mine.host.toString();
		}
		catch(e:Dynamic) {}
		try udp.close() catch(e:Dynamic) {}
		return (local == null || local == '0.0.0.0') ? null : local;
	}

	// A SOAP action of the router's service: the value of `answerField` in the answer ("" if none is asked for), null if it failed
	static function callAction(action:String, args:String, answerField:String):String
	{
		var body:String = '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
			+ 's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:$action xmlns:u="$serviceType">$args</u:$action></s:Body></s:Envelope>';

		var http:haxe.Http = new haxe.Http(controlUrl);
		http.cnxTimeout = 4;
		http.setHeader('Content-Type', 'text/xml; charset="utf-8"');
		http.setHeader('SOAPAction', '"$serviceType#$action"');
		http.setPostData(body);
		var answer:String = null;
		var failed:Bool = false;
		http.onData = function(data:String) answer = data;
		http.onError = function(error:String) failed = true;
		http.request(true);
		if(failed || answer == null) return null;
		if(answerField == null) return '';

		var field:EReg = new EReg('<$answerField>([^<]*)</$answerField>', '');
		return field.match(answer) ? StringTools.trim(field.matched(1)) : null;
	}

	static function httpGet(url:String):String
	{
		var http:haxe.Http = new haxe.Http(url);
		http.cnxTimeout = 4;
		var answer:String = null;
		http.onData = function(data:String) answer = data;
		http.onError = function(error:String) answer = null;
		try http.request(false) catch(e:Dynamic) return null;
		return answer;
	}

	static function hostOf(url:String):String
	{
		var match:EReg = ~/^https?:\/\/([^\/:]+)/;
		return match.match(url) ? match.matched(1) : '';
	}

	static function resolveUrl(base:String, path:String):String
	{
		if(path.startsWith('http://') || path.startsWith('https://')) return path;
		var root:EReg = ~/^(https?:\/\/[^\/]+)/;
		if(!root.match(base)) return path;
		return root.matched(1) + (path.startsWith('/') ? path : '/' + path);
	}
	#end
}
