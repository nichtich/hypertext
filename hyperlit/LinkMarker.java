/**
 * Modification History
 *
 * 2002-May-14   Jason Rohrer
 * Created.
 */



package hyperlit;



import java.io.Serializable;



/**
 * A container class for attributes of a link marker.
 *
 * @author Jason Rohrer
 */
public class LinkMarker implements Serializable {


    
    /**
     * The anchor associated with this link.
     */
    public String mLinkAnchor = null;


    
    /**
     * True iff this link marker is an end marker.
     */
    public boolean mLinkEnd = false;


    
    /**
     * True iff this is both a start and end marker.
     */
    public boolean mLinkStartEnd = false;

    
    
    }
