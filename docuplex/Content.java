/*
 * Modificaton History
 *
 * 2002-February-27   Jason Rohrer
 */



import java.util.ArrayList;

import ContentRegion;



/**
 * Class that maintains a collection of character content.
 *
 * @author Jason Rohrer
 */
public class Content {


    ArrayList mCharList = new ArrayList();

    

    /**
     * Adds a character to this end of this content collection.
     *
     * @param inChar the character to add.
     */
    public void addCharacter( char inChar ) {
        mCharList.add( new CharWrapper( inChar ) );
        }



    /**
     * Gets the number of characters in this collection.
     *
     * @return the number of characters.
     */
    public int getContentLength() {
        return mCharList.size();
        }



    /**
     * Gets the entire content collection as a string.
     *
     * @return a string containing the entire content.
     */
    public String getContentString() {

        char charArray[] = new char[ mCharList.size() ];

        for( int i=0; i<mCharList.size(); i++ ) {
            charArray[i] =
                ( (CharWrapper)( mCharList.get( i ) ) ).mChar;
            }


        return new String( charArray );
        }

    

    /**
     * Gets a region of the content collection as a string.
     *
     * @return a string containing the region.
     */
    public String getContentString( ContentRegion inRegion ) {

        int length = inRegion.getEnd()- inRegion.getStart() + 1;
        
        char charArray[] = new char[ length ];

        for( int i=0; i<length; i++ ) {
            charArray[i] =
                ( (CharWrapper)(
                    mCharList.get( i + inRegion.getStart() ) ) ).mChar;
            }

        return new String( charArray );
        }
    

    }
