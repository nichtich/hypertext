/*
 * Modificaton History
 *
 * 2002-February-27   Jason Rohrer
 */




/**
 * Class that describes a contiguous region of content.
 *
 * @author Jason Rohrer.
 */
public class ContentRegion implements Cloneable {


    protected int mStart;
    protected int mEnd;


    
    /**
     * Constructs a region.
     *
     * @param inStart the start of the region, in characters.
     * @param inEnd the end of the region, in characters.
     */
    public ContentRegion( int inStart, int inEnd ) {
        mStart = inStart;
        mEnd = inEnd;
        }



    /**
     * Gets the start of this region.
     *
     * @return the start of this region, in characters.
     */
    public int getStart() {
        return mStart;
        }



    /**
     * Gets the end of this region.
     *
     * @return the end of this region, in characters.
     */
    public int getEnd() {
        return mEnd;
        }



    /**
     * Copies this region.
     *
     * @return a copy of this region.
     */
    public ContentRegion copy() {
        return new ContentRegion( getStart(), getEnd() );
        }

    

    /**
     * Gets a string representing this region.
     *
     * @return this region as a string.
     */
    public String toString() {
        return "<" + getStart() + "," + getEnd() + ">";
        }

    

    /**
     * Splits this region, producing two new regions.
     *
     * @param inRelativeSplitIndex the index of the last character
     *   before the split, relative to getStart().  Must be at least 0
     *   and less than getEnd() - getStart().
     *
     * @return an array containing the two new regions.
         or null if the split index is out of bounds.
     */
    public ContentRegion [] split( int inRelativeSplitIndex ) {

        if( inRelativeSplitIndex >= 0 &&
            inRelativeSplitIndex < getEnd() - getStart() ) {

            ContentRegion regions[] = new ContentRegion[ 2 ];
            
            regions[0] = new ContentRegion(
                mStart, mStart + inRelativeSplitIndex );
            regions[1] = new ContentRegion(
                mStart + inRelativeSplitIndex + 1, mEnd );

            return regions;
            }
        else {
            return null;
            }
        }


    
    }
