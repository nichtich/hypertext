/*
 * Modificaton History
 *
 * 2002-February-27   Jason Rohrer
 * Created.
 *
 * 2002-February-28   Jason Rohrer
 * Added versioning support.
 */




import java.util.ArrayList;


import ContentRegion;
import Content;


/**
 * Class that maintains a collection of content regions comprising a view.
 *
 * @author Jason Rohrer
 */
public class View {


    protected ArrayList mRegions = new ArrayList();

    protected Content mContent;


    protected ArrayList mCopyBuffer = new ArrayList();
    

    /**
     * Constructs an empty view of content.
     *
     * @param inContent the content to view.
     */
    public View( Content inContent ) {
        mContent = inContent;
        }



    /**
     * Adds a character to this view.
     *
     * @param inChar the character to add.
     * @param inViewPosition the position in this view where the character
     *    will be added.
     */
    public void addCharacter( char inChar, int inViewPosition ) {
        
        int regionIndex = getHitRegion( inViewPosition );
        int relativeIndex = getHitRegionRelativeIndex( inViewPosition );


        if( relativeIndex == 0 && regionIndex != 0 ) {
            regionIndex = getHitRegion( inViewPosition - 1 );
            relativeIndex =
                getHitRegionRelativeIndex( inViewPosition - 1 ) + 1;
            }
        
        
        // watch for init case when no region hit
        // (when we're at the end of the view)
        if( regionIndex == -1 ) {
            if( mRegions.size() == 0 ) {
                // create our first region
                mRegions.add(
                    0,
                    new ContentRegion( mContent.getContentLength(),
                                       mContent.getContentLength() ) );

                mContent.addCharacter( inChar );

                return;
                }
            else {
                // set up so that the "after" insertion code
                // below will handle it

                regionIndex = getHitRegion( inViewPosition - 1 );
                relativeIndex =
                    getHitRegionRelativeIndex( inViewPosition - 1 ) + 1;
                }
            }

        ContentRegion region = (ContentRegion)( mRegions.get( regionIndex ) );
        int regionLength = region.getEnd() - region.getStart() + 1;

        
        if( relativeIndex == 0 ) {
            // insert before this region
            
            mRegions.add( regionIndex,
                          new ContentRegion( mContent.getContentLength(),
                                             mContent.getContentLength() ) );

            mContent.addCharacter( inChar );            
            }
        else if( relativeIndex == regionLength ) {
            // insert after this region
            
            if( region.getEnd() == mContent.getContentLength() - 1 ) {
                // add on to this region
                mRegions.remove( regionIndex );

                mRegions.add(
                    regionIndex,
                    new ContentRegion( region.getStart(),
                                       mContent.getContentLength() ) );
                }
            else {
                // start a new region after this region
                mRegions.add(
                    regionIndex + 1,
                    new ContentRegion( mContent.getContentLength(),
                                       mContent.getContentLength() ) );
                }
            
            mContent.addCharacter( inChar );
            }
        else {
            // insert into middle of this region
            
            mRegions.remove( regionIndex );
            
            ContentRegion newRegions[] = region.split( relativeIndex - 1 );

            // add last region
            mRegions.add( regionIndex, newRegions[1] );
            // then new middle region
            mRegions.add( regionIndex,
                          new ContentRegion( mContent.getContentLength(),
                                             mContent.getContentLength() ) );
            // then first region
            mRegions.add( regionIndex, newRegions[0] );

            
            mContent.addCharacter( inChar );
            }


        }


    
    /**
     * Deletes a character from this view.
     * @param inViewPosition the position in this view of the character
     *    to delete.
     */
    public void deleteCharacter( int inViewPosition ) {

        int regionIndex = getHitRegion( inViewPosition );
        int relativeIndex = getHitRegionRelativeIndex( inViewPosition );

        ContentRegion region = (ContentRegion)( mRegions.get( regionIndex ) );
        int regionLength = region.getEnd() - region.getStart() + 1;
        
        if( relativeIndex == 0 ) {
            // remove first character
            mRegions.remove( regionIndex );

            if( regionLength > 1 ) {
                mRegions.add(
                    regionIndex,
                    new ContentRegion( region.getStart() + 1,
                                       region.getEnd() ) );
                }
            else {
                // check if surrounding regions should be joined.
                if( regionIndex != 0 ) {
                    checkAndJoin( regionIndex - 1 );
                    }
                }
            }
        else if( relativeIndex == regionLength - 1 ) {
            // remove last character
            mRegions.remove( regionIndex );

            if( regionLength > 1 ) {
                            
                mRegions.add(
                    regionIndex,
                    new ContentRegion( region.getStart(),
                                       region.getEnd() - 1 ) );
                }
            else {
                // check if surrounding regions should be joined.
                if( regionIndex != 0 ) {
                    checkAndJoin( regionIndex - 1 );
                    }
                }
            }
        else {
            // split region, removing middle character
            mRegions.remove( regionIndex );

            // add last part of split region
            mRegions.add(
                regionIndex,
                new ContentRegion( region.getStart() + relativeIndex + 1,
                                   region.getEnd() ) );
            // add first part of split region
            mRegions.add(
                regionIndex,
                new ContentRegion( region.getStart(),
                                   region.getStart() + relativeIndex - 1 ) );
            }

        }



    /**
     * Copy a region from the underlying content.
     *
     * @param inStart the start of the region in characters.
     * @param inEnd the end of the region (the last character).
     */
    public void contentCopy( int inStart, int inEnd ) {
        mCopyBuffer.clear();
        mCopyBuffer.add( new ContentRegion( inStart, inEnd ) );
        }


    
    /**
     * Copy a region from the view, tracking the underlying content.
     *
     * @param inStart the start of the region in characters.
     * @param inEnd the end of the region (the last character).
     */
    public void viewCopy( int inStart, int inEnd ) {
        int startRegionIndex = getHitRegion( inStart );
        int endRegionIndex = getHitRegion( inEnd );
        
        ContentRegion startRegion =
            (ContentRegion)( mRegions.get( startRegionIndex ) );
        ContentRegion endRegion =
            (ContentRegion)( mRegions.get( endRegionIndex ) ); 
        
        mCopyBuffer.clear();

        if( startRegionIndex == endRegionIndex ) {
            mCopyBuffer.add( new ContentRegion(
                startRegion.getStart() +
                getHitRegionRelativeIndex( inStart ),
                startRegion.getStart() +
                getHitRegionRelativeIndex( inEnd ) ) ); 
            }
        else {
        
            mCopyBuffer.add( new ContentRegion(
                startRegion.getStart() + getHitRegionRelativeIndex( inStart ),
                startRegion.getEnd() ) );
        
            for( int i=startRegionIndex + 1; i<endRegionIndex; i++ ) {
                ContentRegion region =
                    (ContentRegion)( mRegions.get( i ) );
                mCopyBuffer.add( region.copy() );
                }

            mCopyBuffer.add( new ContentRegion(
                endRegion.getStart(),
                endRegion.getStart() + getHitRegionRelativeIndex( inEnd ) ) );
                         
            }
                         
        }



    /**
     * Pastes the current copy buffer into this view.
     *
     * @param inLocation the location in characters.
     */
    public void viewPaste( int inLocation ) {
        if( mCopyBuffer.size() == 0 ) {
            return;
            }

        if( mRegions.size() == 0 ) {
            mRegions.addAll( mCopyBuffer );
            return;
            }
        
        int regionIndex = getHitRegion( inLocation );
        int relativeIndex = getHitRegionRelativeIndex( inLocation );

        if( regionIndex == -1 ) {
            regionIndex = getHitRegion( inLocation - 1 );
            relativeIndex = getHitRegionRelativeIndex( inLocation - 1 ) + 1;
            }
        
        int pasteIndex;

        ContentRegion region =
            (ContentRegion)( mRegions.get( regionIndex ) ); 

        int regionLength = region.getEnd() - region.getStart() + 1;
        
        if( relativeIndex >= regionLength ) {
            // paste after
            pasteIndex = regionIndex + 1;
            }
        else if( relativeIndex == 0 ) {
            // paste before
            pasteIndex = regionIndex;
            }
        else {
            // split to paste
            mRegions.remove( regionIndex );
            ContentRegion newRegions[] =
                region.split( relativeIndex - 1 );

            // add in reverse order
            mRegions.add( regionIndex, newRegions[1] );
            mRegions.add( regionIndex, newRegions[0] );

            pasteIndex = regionIndex + 1;
            }

        
        // add the buffered regions to the pasteIndex in reverse order
        for( int i=mCopyBuffer.size()-1; i>=0; i-- ) {
            mRegions.add( pasteIndex, mCopyBuffer.get( i ) );
            }

        // look for regions that need to be joined
        if( pasteIndex + mCopyBuffer.size() != 0 ) {
            checkAndJoin( pasteIndex + mCopyBuffer.size() - 1 );
            }
        if( pasteIndex != 0 ) {
            checkAndJoin( pasteIndex - 1 );
            }
        
        }



    /**
     * Gets the current version.
     *
     * @return the current version as a list.
     */
    public ArrayList getCurrentVersion() {
        return new ArrayList( mRegions );
        }


    
    /**
     * Sets the current version.
     *
     * @param inVersion the new version.
     */
    public void setVersion( ArrayList inVersion ) {
        mRegions = new ArrayList( inVersion );
        }
    

    
    /**
     * Gets the text of this view.
     *
     * @return the view as a string.
     */
    public String getViewText() {
        String list = "";
        for( int i=0; i<mRegions.size(); i++ ) {
            ContentRegion region = (ContentRegion)( mRegions.get( i ) );
            list = list + mContent.getContentString( region );
            }
        return list;
        }

    
    
    /**
     * Get the region list for this view as a formatted string.
     *
     * @return the region list as a string.
     */
    public String getRegionList() {
        String list = "";
        for( int i=0; i<mRegions.size(); i++ ) {
            ContentRegion region = (ContentRegion)( mRegions.get( i ) );

            list = list + region.toString() + "\n    "
                + "{" + mContent.getContentString( region ) + "}\n";
            }
        return list;
        }



    /**
     * Checks if two regions should be joined and joins them.
     *
     * @param inLeftIndex the left region index.
     * @param inRightIndex the right region index.
     */
    protected void checkAndJoin( int inLeftIndex ) {
        // check if surrounding regions should be joined.
        if( inLeftIndex != mRegions.size() - 1 ) {
            ContentRegion leftRegion =
                (ContentRegion)( mRegions.get( inLeftIndex  ) );
            ContentRegion rightRegion =
                (ContentRegion)( mRegions.get( inLeftIndex + 1 ) );

            if( leftRegion.getEnd() == rightRegion.getStart() - 1 ) {
                // join them
                mRegions.remove( inLeftIndex + 1 );
                mRegions.remove( inLeftIndex );

                mRegions.add( inLeftIndex,
                             new ContentRegion(
                                 leftRegion.getStart(),
                                 rightRegion.getEnd() ) );
                }                    
            }
        }
    


    /**
     * Gets the region containing this view position.
     *
     * @param inViewPosition the position.
     *
     * @return the index of the region containing inViewPosition.
     */
    protected int getHitRegion( int inViewPosition ) {

        int currentViewIndex = 0;
        
        for( int i=0; i<mRegions.size(); i++ ) {
            ContentRegion region = (ContentRegion)( mRegions.get( i ) );

            currentViewIndex += region.getEnd() - region.getStart() + 1;

            if( currentViewIndex > inViewPosition ) {
                return i;
                }
            }

        return -1;
        }



    /**
     * Gets the Relative index into the region containing this view position.
     *
     * @param inViewPosition the position.
     *
     * @return the index into the region containing inViewPosition.
     */
    protected int getHitRegionRelativeIndex( int inViewPosition ) {

        int currentViewIndex = 0;
        
        for( int i=0; i<mRegions.size(); i++ ) {
            ContentRegion region = (ContentRegion)( mRegions.get( i ) );

            int regionLength = region.getEnd() - region.getStart() + 1;
            
            int viewRegionEnd = currentViewIndex + regionLength;
            
            if( viewRegionEnd > inViewPosition ) {
                return inViewPosition - currentViewIndex;
                }

            currentViewIndex = viewRegionEnd;
            }

        return -1;
        }

    

    }

