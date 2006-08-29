/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        Initial release: April 2004      
        
        author:         Kris

*******************************************************************************/

module mango.net.servlet.model.IServletResponse;

private import  tango.io.model.IBuffer;

private import  tango.net.http.HttpWriter,
                tango.net.http.HttpParams,
                tango.net.http.HttpCookies,
                tango.net.http.HttpHeaders,
                tango.net.http.HttpResponses;

private import  mango.net.servlet.ServletContext;

/******************************************************************************

******************************************************************************/

interface IServletResponse
{
        /**********************************************************************

        **********************************************************************/

        HttpParams getParameters ();

        /**********************************************************************

        **********************************************************************/

        HttpCookies getCookies ();

        /**********************************************************************

        **********************************************************************/

        HttpHeaders getHeaders ();

        /***********************************************************************
        
        ***********************************************************************/

        HttpWriter getWriter();

        /***********************************************************************
        
        ***********************************************************************/

        void setContentLength (int len);

        /***********************************************************************
        
        ***********************************************************************/

        void setContentType (char[] type);

        /***********************************************************************
        
        ***********************************************************************/

        void flushBuffer();

        /***********************************************************************
        
        ***********************************************************************/

        void sendError (inout HttpStatus status, char[] msg);

        /***********************************************************************
        
        ***********************************************************************/

        void sendError (inout HttpStatus status);

        /***********************************************************************
        
        ***********************************************************************/

        void sendRedirect(char[] location);

        /***********************************************************************
        
        ***********************************************************************/

        void setStatus (inout HttpStatus status);

        /***********************************************************************
        
        ***********************************************************************/

        bool copyFile (ServletContext context, char[] path);
}
