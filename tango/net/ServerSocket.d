/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: March 2004      
                        Outback release: December 2006
        
        author:         Kris

*******************************************************************************/

module tango.net.ServerSocket;

private import  tango.net.Socket,
                tango.net.SocketConduit;

public  import  tango.net.InternetAddress;

/*******************************************************************************

        ServerSocket is a wrapper upon the basic socket functionality to
        simplify the API somewhat. You use a ServerSocket to listen for 
        inbound connection requests, and get back a SocketConduit when a
        connection is made.

        Accepted SocketConduit instances are held in a free-list to help
        avoid heap activity. These instances are recycled upon invoking
        the close() method, and one should ensure that occurs

*******************************************************************************/

class ServerSocket
{
        private Socket  socket;
        private int     linger = -1;

        /***********************************************************************
        
                Construct a ServerSocket on the given address, with the
                specified number of backlog connections supported. The
                socket is bound to the given address, and set to listen
                for incoming connections. Note that the socket address 
                can be setup for reuse, so that a halted server may be 
                restarted immediately.

        ***********************************************************************/

        this (InternetAddress addr, int backlog=32, bool reuse=false)
        {
                socket = new Socket (AddressFamily.INET, SocketType.STREAM, ProtocolType.IP);
                socket.create.setAddressReuse(reuse).bind(addr).listen(backlog);
        }

        /***********************************************************************
        
                Set the period in which dead sockets are left lying around
                by the O/S

        ***********************************************************************/

        void setLingerPeriod (int period)
        {
                linger = period;
        }

        /***********************************************************************
        
                Return the wrapped socket

        ***********************************************************************/

        Socket getSocket ()
        {
                return socket;
        }

        /***********************************************************************
        
                Wait for a client to connect to us, and return a connected
                SocketConduit.

        ***********************************************************************/

        SocketConduit accept ()
        {
                auto wrapper = SocketConduit.allocate();
                auto accepted = socket.accept (wrapper.getSocket);

                // force abortive closure to avoid prolonged OS scavenging?
                if (linger >= 0)
                    accepted.setLingerPeriod (linger);

                return wrapper;
        }
}
