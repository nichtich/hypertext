/**
 * Modification History
 *
 * 2002-May-14   Jason Rohrer
 * Created.
 * Added support for writing lexia as html.
 */



package hyperlit;



import hyperlit.LinkMarker;

import java.util.ArrayList;

import java.io.OutputStream;
import java.io.PrintStream;
import java.io.Serializable;



/**
 * A hypertext node (aka a lexia).
 *
 * @author Jason Rohrer
 */
public class Lexia implements Serializable {



    public Lexia() {
        mName = "" + sLexiaCount;
        sLexiaCount++;
        }

    
    
    public Lexia( String inName ) {
        mName = inName;
        }



    public static int getLexiaCount() {
        return sLexiaCount;
        }


    
    public static void setLexiaCount( int inLexiaCount ) {
        sLexiaCount = inLexiaCount;
        }

    


    public String mName;

    
    
    /**
     * A string containing the plain text of this lexia.
     */
    public String mText = "";



    /**
     * An array list that is the same length as mText containing
     * LinkMarkers for the text of this lexia.
     *
     * If no link marker is associated with a particular character from
     * the lexia text string, then the correspoinding array list
     * position is set to null.
     */
    public ArrayList mLinkMarkerList = new ArrayList();



    /**
     * Writes this lexia out as HTML.
     *
     * If an anchor value of ANCHOR occurs in this lexia, it is
     * encoded in HTML as <A HREF="ANCHOR.shtml"></A>.
     *
     * @param inOutputStream the stream to write this lexia out on.
     */
    public void writeHTML( OutputStream inOutputStream ) {
        PrintStream printStream = new PrintStream( inOutputStream );

        printStream.println( "<!--#include virtual=\"header.html\" -->" );

        int numChars = mText.length();

        for( int i=0; i<numChars; i++ ) {

            LinkMarker marker = (LinkMarker)( mLinkMarkerList.get( i ) );

            if( marker != null ) {
                if( ! marker.mLinkEnd ) {
                    printStream.print(
                        "<A HREF=\"" + marker.mLinkAnchor +
                        ".shtml\">" );
                    }
                }

            printStream.print( mText.charAt( i ) );
            
            
            if( marker != null ) {
                if( marker.mLinkEnd || marker.mLinkStartEnd ) {
                    printStream.print( "</A>" );
                    }
                }
            
            }

        printStream.println();
        printStream.println( "<!--#include virtual=\"footer.html\" -->" );
        }   


    
    public String toString() {
        if( mText.length() == 0 ) {
            return mName;
            }
        else {
            if( mText.length() < 10 ) {
                return mText.substring( 0, mText.length() );
                }
            else {
                return mText.substring( 0, 10 );
                }
            }
        }


    
    protected static int sLexiaCount = 0;

    
    
    }
