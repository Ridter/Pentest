<?php
	error_reporting(E_ALL);
	ini_set('display_errors', true);
	ini_set('html_errors', false);


	function errorlog($log)
	{
		$DEBUG=FALSE;

		if($DEBUG)
		{
			error_log($log);
		}
	}

	function check_sock_error($area)
	{
		$err = socket_last_error();

		if($err>0)
		{
			errorlog("CHECK_SOCK_ERROR(".$area."): ".socket_strerror(socket_last_error()));
			socket_clear_error();
		}
	}

	function handle_exceptions(&$es)
	{
		foreach($es as $s)
		{
			errorlog("BACKEND: Got exception on socket ".$s);
		}
	}

	function send_command($port,$data)
	{
		$sock = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
		$ret = socket_sendto($sock, $data, strlen($data), 0, '127.0.0.1', $port);

        check_sock_error("FRONTEND send_command");

		errorlog("FRONTEND: send_command '".$data."' on port ".$port." returned ".$ret);

		return $ret;
	}

	function get_socket_key(&$sockets,&$readsocket)
	{
		foreach($sockets as $key => $value)
		{
			if($value === $readsocket)
			{
				return $key;
			}
		}

		return false;
	}

	function handle_admin(&$admin, &$sockets, &$sockets_seq_data, &$sockets_next_seq, &$clientdata)
	{
		$from = '';
		$rport = 0;
        $buf='';
		socket_recvfrom($admin, $buf, 2*1024*1024, 0, $from, $rport);
	
		#errorlog("BACKEND: ADMIN sockets='".var_export($sockets,TRUE)."'");
		#errorlog("BACKEND: ADMIN Received '".$buf."' from ".$from);

		if($buf == 'die')
		{
			return true;
		}
		else
		{
			$parts = split(":", $buf);

			if($parts[0] == 'createSocket')
			{
				$socketNumber = $parts[1];
				$targetHost = $parts[2];
				$targetPort = $parts[3];

				errorlog("BACKEND: createSocket with socketNumber ".$socketNumber.", host ".$targetHost.", port ".$targetPort);

				$socket = socket_create(AF_INET, SOCK_STREAM, getprotobyname('tcp'));

				if($socket)
				{
					$result = socket_connect($socket,$targetHost, $targetPort);

					if($result)
					{
						errorlog("BACKEND: Connection succeeded");

						$key = $targetHost.":".$targetPort.":".$socketNumber;
						$sockets[$key] = $socket;
						errorlog("BACKEND: ADMIN sockets are now '".var_export($sockets,TRUE)."' after adding socket ".$socket." with key ='".$key."'");
					}
					else
					{
						errorlog("BACKEND: Connect failed");
					}
				}
				else
				{
					errorlog("BACKEND: Cannot create socket");
				}
			}
			else if($parts[0] == 'newData')
			{
				$socketNumber = $parts[1];
				$targetHost = $parts[2];
				$targetPort = $parts[3];
				$sequenceNumber = $parts[4];

				$sockkey = $targetHost.":".$targetPort.":".$socketNumber;
				$socket = $sockets[$sockkey];

                if($sequenceNumber == 0)
                {
                    $sockets_next_seq[$sockkey] = 0;
                    $sockets_seq_data = array();
                }

				if($parts[5] == '*')
				{
					errorlog("BACKEND: newData(".$sequenceNumber."), Client requested closing of socket ".$socket." with key ".$sockkey);
					socket_close($socket);
					unset($sockets[$sockkey]);
                    unset($sockets_next_seq[$sockkey]);
                    unset($sockets_seq_data[$sockkey]);
				}
				else if(!$socket)
				{
					errorlog("BACKEND: newData(".$sequenceNumber."), Client attempted to send '".$parts[5]."' to ".$sockkey);
					errorlog("BACKEND: newData(".$sequenceNumber."), available sockets are:".var_export($sockets,TRUE));

					array_push($clientdata,'[data]'.$sockkey.":*");
				}
				
				else
				{
					$data = str_replace(" ", "+", $parts[5]);
					$data = base64_decode($data);

                    errorlog("BACKEND: newData(".$sequenceNumber.") with socketNumber ".$socketNumber.", host ".$targetHost.", port ".$targetPort.", data '".$data."'");

                    $sockets_seq_data[$sockkey][$sequenceNumber] = $data;

                    if($sockets_next_seq[$sockkey] == $sequenceNumber)
                    {

                        while(array_key_exists($sockets_next_seq[$sockkey], $sockets_seq_data[$sockkey] ))
                        {
                            if($socket)
                            {
                                $ret = socket_send($socket, $data, strlen($data), 0);
                                check_sock_error("BACKEND newData");
                                errorlog("BACKEND: newData(".$sequenceNumber."), socket send to '".$sockkey." returned ".$ret);
                            }
                            else
                            {
                                errorlog("BACKEND: newData(".$sequenceNumber."), Unknown socket ".$sockkey);
                            }

                            $sockets_next_seq[$sockkey]++;
                        }
                    }
                    else
                    {
                        if($sockets_next_seq[$sockkey] < $sequenceNumber) #This packet is out of order, we are still waiting for one(s) before this one.
                        {
                            error_log("BACKEND: newData(".$sequenceNumber.") has been queued, current sequence number required is ".$sockets_next_seq[$sockkey]);
                        }
                        else #$sockets_next_seq[$sockkey] is > sequenceNumber
                        {
                        }
                    }
				}

			}
			else if($parts[0] == 'getData')
			{
				$val = array_shift($clientdata);

				if($val)
				{
                    $ret = socket_sendto($admin, $val, strlen($val), 0, $from, $rport);
                    check_sock_error("BACKEND getData with data");
                    errorlog("BACKEND: getData, Sent ".$ret." bytes from ".strlen($val));
				}
				else
				{
					$val = '[NO_NEW_DATA]';
					$ret = socket_sendto($admin, $val, strlen($val), 0, $from, $rport);
                    check_sock_error("BACKEND getData [NO_NEW_DATA]");
				}
			}
			else
			{
				errorlog("BACKEND: Unknown part '".$parts[0]."'");
			}
		}

		return false;
	}


	set_time_limit(0);

	if(array_key_exists('action',$_REQUEST))
	{
		$action = $_REQUEST['action'];

		if($action == 'checkPort')
		{
			$port = $_REQUEST['port'];

			$sock = socket_create(AF_INET, SOCK_DGRAM, getprotobyname('udp'));
			if($sock)
			{
				$result = socket_bind($sock, '127.0.0.1', $port);
				if($result)
				{
					errorlog("FRONTEND: checkPort, Could bind to port".$port."\n");
					echo "Success\n";
				}
				else
				{
					errorlog("FRONTEND: checkPort, FAILED bind to port".$port."\n");
					echo "Cannot bind socket to 127.0.0.1:".$port."\n";
				}
			}
			else
			{
				echo "FRONTEND: checkPort, Cannot create socket\n";
			}

			socket_close($sock);

		}
		else if($_REQUEST['action'] == 'startReDuh')
		{
			$sockets = array();
            $sockets_seq_data = array();
            $sockets_next_seq = array();
			$clientdata = array();

			$port = $_REQUEST['servicePort'];
			$admin = socket_create(AF_INET, SOCK_DGRAM, getprotobyname('udp'));
			if ( ! socket_bind($admin, 0, $port) )
			{
				echo "Cannot bind admin socket\n";
				errorlog("BACKEND: startReDuh, FAILED to bind admin socket on port ".$port);
				exit();
			}
			else
			{
				errorlog("BACKEND: startReDuh, Admin port ".$admin." bound on port ".$port);
			}

		
			errorlog("BACKEND: Starting reduh loop");

			$done=false;

			while(!$done)
			{
				$rs = array($admin) + $sockets;
				$ws = NULL;
				$es = array($admin) + $sockets;

				#errorlog("Doing select with read sockets ".count($rs)." '".var_export($rs,TRUE)."'");

				$n = socket_select($rs, $ws, $es,0,1000000); 

				check_sock_error("BACKEND select");

				if(count($es)>0)
				{
					handle_exceptions($es);
				}

				if($n === false)
				{
					errorlog("BACKEND: socket_select: ".socket_strerror(socket_last_error()));
				}
				else if($n > 0)
				{
					#errorlog("BACKEND: select returned n=".$n);

					foreach ($rs as $readsocket)
					{
						#errorlog("BACKEND: Read for socket ".$readsocket);
						if($readsocket === $admin)
						{
							$done = handle_admin($admin,$sockets,$sockets_seq_data,$sockets_next_seq,$clientdata);				
						}
						else #Its a non-admin socket
						{
							errorlog("BACKEND: *** Data for created socket ".$readsocket);	

							$sockkey = get_socket_key($sockets,$readsocket);

							if($sockkey)
							{
								errorlog("BACKEND: *** Socket key is ".$sockkey);

								$data = '';
								$ret = socket_recv($readsocket, $data,2*1024*1024,0);
                                check_sock_error("BACKEND recv from readsocket");

								#errorlog("BACKEND: *** recv returned data '".$data."' with ret=".$ret." on socket ".$readsocket);


								if($data == NULL)
								{
									errorlog("BACKEND: *** Socket ".$readsocket." has been closed");
									array_push($clientdata,"[data]".$sockkey.":*");
									socket_close($readsocket);

									unset($sockets[$sockkey]);
								}
								else
								{
                                    while(strlen($data) > 0)
                                    {
                                        $tmp = substr($data,0,32*1024);
                                        $b64data = base64_encode($tmp);
                                        errorlog("BACKEND: *** Added ".strlen($b64data)." bytes to queue");
                                        array_push($clientdata,"[data]".$sockkey.":".$b64data);

                                        $data = substr($data,32*1024);
                                    }
								}
							}
							else
							{
								errorlog("BACKEND: Unknown socket");
							}
						}
					}
				}
				#sleep(1);
			}

			errorlog("BACKEND: reduh is quiting");

			socket_close($admin);
		}
		else if($_REQUEST['action'] == 'killReDuh')
		{
			$port = $_REQUEST['servicePort'];

			send_command($port,"die");

			echo "Success\n";
		}
		else if($_REQUEST['action'] == 'getData')
		{
			$servicePort = $_REQUEST['servicePort'];

			$done = false;
			$p = 30000;

			while(!$done)
			{
				$admin = socket_create(AF_INET, SOCK_DGRAM, getprotobyname('udp'));
				if ($admin && socket_bind($admin, 0, $p) )
				{
					$done = true;
				}
				else
				{
					$p++;
				}
			}

			if($admin)
			{
				$data = 'getData';
				$ret = socket_sendto($admin, $data, strlen($data), 0, '127.0.0.1', $servicePort);
                check_sock_error("FRONTEND getData");
				#errorlog("FRONTEND: Sending getData on port ".$p." ret is ".$ret);

				$rs = array($admin);
				$ws = NULL;
				$es = NULL;
				$n = socket_select($rs,$ws,$es,1,0);

				if($n > 0)
				{
					$recv = socket_read($admin,2*1024*1024);
					#errorlog("FRONTEND: Got data from backend: '".$recv."'");
					echo $recv."\n";
				}
				else
				{
					echo "[NO_NEW_DATA]\n";
				}

				socket_close($admin);
			}
			else
				echo "[NO_NEW_DATA]\n";
		}
		else if($_REQUEST['action'] == 'createSocket')
		{
			$servicePort = $_REQUEST['servicePort'];
			$socketNumber = $_REQUEST['socketNumber'];
			$targetHost = $_REQUEST['targetHost'];
			$targetPort = $_REQUEST['targetPort'];

			$msg = "createSocket:".$socketNumber.":".$targetHost.":".$targetPort;

			send_command($servicePort,$msg);

			echo "Success\n";
		}
		else if($_REQUEST['action'] == "newData")
		{
			$servicePort = $_REQUEST['servicePort'];
			$socketNumber = $_REQUEST['socketNumber'];
			$targetHost = $_REQUEST['targetHost'];
			$targetPort = $_REQUEST['targetPort'];
            $sequenceNumber = $_REQUEST['sequenceNumber'];
			$data = $_REQUEST['data'];

			$msg = "newData:".$socketNumber.":".$targetHost.":".$targetPort.":".$sequenceNumber.":".$data;

			send_command($servicePort,$msg);

			echo "Success\n";
		}
		else
		{
			errorlog("Unknown action '".$_REQUEST['action']."'");
			echo "Unknown action '".$_REQUEST['action']."'\n";
		}
	} 
	else
	{
		echo "Unknown request to ReDuh!\n";
	}
?>
