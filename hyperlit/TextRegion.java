/**
 * Modification History
 *
 * 2002-May-14   Jason Rohrer
 * Created.
 */



package hyperlit;


class TextRegion {



    /**
     * Constructs a region.
     *
     * @param inStart the start of the region as a character offset.
     * @param inEnd the end of the region as a character offset.
     */
    TextRegion( int inStart, int inEnd ) {
        mStart = inStart;
        mEnd = inEnd;
        }

    

    /**
     * Gets the start of this region.
     *
     * @return the start of the region as a character offset.
     */
    public int getStart() {
        return mStart;
        }


    
    /**
     * Gets the end of this region.
     *
     * @return the end of the region as a character offset.
     */    
    public int getEnd() {
        return mEnd;
        }



    protected int mStart;
    protected int mEnd;
    
    

    }
