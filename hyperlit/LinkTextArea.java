/**
 * Modification History
 *
 * 2002-May-14   Jason Rohrer
 * Created.
 * Added support for querying link anchors.
 * Optimized updateDocument.
 */



package hyperlit;

import hyperlit.TextRegion;
import hyperlit.LinkMarker;
import hyperlit.Lexia;



import javax.swing.JTextPane;

import javax.swing.text.Document;
import javax.swing.text.Style;
import javax.swing.text.StyleConstants;
import javax.swing.text.StyleContext;
import javax.swing.text.BadLocationException;


import javax.swing.event.CaretEvent;
import javax.swing.event.CaretListener;

import javax.swing.SwingUtilities;

import java.util.ArrayList;



/**
 * A text area that supports link anchors.
 *
 * @author Jason Rohrer.
 */
class LinkTextArea extends JTextPane {



    /**
     * Constructs a text area.
     */
    public LinkTextArea() {

        // Create the styles we need.
        // Initialize some styles.
        Style defaultStyle =
            StyleContext.getDefaultStyleContext().
                getStyle( StyleContext.DEFAULT_STYLE );

        Style regular = addStyle( "regular", defaultStyle );

        Style s = addStyle( "underline", regular );
        StyleConstants.setUnderline( s, true );

        addCaretListener( new TextChangeListener() );

        setLexia( new Lexia() );
        }



    /**
     * Sets the text and links of this text area
     * to those from a lexia.
     *
     * @param inLexia the lexia to set this text area to.
     */
    public void setLexia( Lexia inLexia ) {
        mText = inLexia.mText;
        mLinkMarkerList = inLexia.mLinkMarkerList;
        mLexiaName = inLexia.mName;

        mIgnoreCaret[0] = true;
        setCaretPosition( 0 );
        mIgnoreCaret[0] = false;

        updateDocument();
        }



    /**
     * Gets the text and links of this text area as a lexia.
     *
     * @return this text area as a lexia.
     */
    public Lexia getLexia() {
        Lexia lexia = new Lexia( mLexiaName );
        
        lexia.mText = mText;
        lexia.mLinkMarkerList = mLinkMarkerList;

        return lexia;
        }
    
    

    /**
     * Gets the word under the current caret position.
     *
     * @return the word as a region.
     */
    public TextRegion getCurrentCaretWord() {
        String text = getText();

        if( text.length() == 0 ) {
            return new TextRegion( 0, 0 );
            }
        
        int position = getCaretPosition();
        if( position == text.length() ) { 
            position = position - 1;
            }

        if( text.charAt( position ) == ' ' ) {
            return new TextRegion( position, position );
            }
        
        // position is not on whitespace
        
        // look back for whitespace
        int backPosition = position;
        while( backPosition > 0 && text.charAt( backPosition ) != ' ' ) {
            backPosition--;
            }

        // backPosition on whitespace, move up to word
        if( text.charAt( backPosition ) == ' ' &&
            backPosition != text.length() - 1 ) {

            backPosition++;
            }

        // look forward for whitespace
        int forwardPosition = position;

        while( forwardPosition < text.length() - 1
               && text.charAt( forwardPosition ) != ' ' ) {

            forwardPosition++;
            }

        // forwardPosition on whitespace, move back to word
        if( text.charAt( forwardPosition ) == ' ' &&
            forwardPosition != 0 ) {
            forwardPosition--;
            }


        if( forwardPosition < backPosition ) {
            forwardPosition = backPosition;
            }

        return new TextRegion( backPosition, forwardPosition );        
        }



    /**
     * Adds a link to a region.
     *
     * @param inRegion the region to add a link to.
     * @param inAnchor the anchor to add to this region.
     */
    public void addLinkToRegion( TextRegion inRegion, String inAnchor ) {

        if( mLinkMarkerList.size() > 0 ) {
            
            if( inRegion.getStart() != inRegion.getEnd() ) {
                LinkMarker start = new LinkMarker();
                start.mLinkAnchor = inAnchor;
                
                LinkMarker end = new LinkMarker();
                end.mLinkEnd = true;
        
            
                mLinkMarkerList.set( inRegion.getStart(), start );
                mLinkMarkerList.set( inRegion.getEnd(),  end );
                }
            else {
                LinkMarker startEnd = new LinkMarker();
                startEnd.mLinkAnchor = inAnchor;
                startEnd.mLinkStartEnd = true;
            
                mLinkMarkerList.set( inRegion.getEnd(),  startEnd );
                }
            updateDocument();
            }
        }



    /**
     * Clears links from a region.
     *
     * @param inRegion the region to clear links from.
     */
    public void clearLinksFromRegion( TextRegion inRegion ) {

        if( mLinkMarkerList.size() > 0 ) {
            int start = inRegion.getStart();
            int end = inRegion.getEnd();
            
            for( int i=start; i<=end; i++ ) {
                mLinkMarkerList.set( i, null );
                }        
            
            updateDocument();
            }
        }



    /**
     * Gets the link anchor from a particular character position.
     *
     * @param inPosition the character position to get an anchor from.
     *
     * @return the anchor, nor NULL if no link start marker is present.
     */
    public String getLinkAnchor( int inPosition ) {
        LinkMarker marker = (LinkMarker)( mLinkMarkerList.get( inPosition ) );
        if( marker != null ) {
            // will be null if not a start marker
            return marker.mLinkAnchor;
            }
        else {
            return null;
            }
        }

    

    protected String mLexiaName = "";
    protected String mText = "";
    protected ArrayList mLinkMarkerList = new ArrayList();
    protected final boolean mIgnoreCaret[] = { false };

    

    /**
     * Refills the document view from mText and mLinks arrays.
     */
    protected void updateDocument() {
        mIgnoreCaret[0] = true;

        int caretPosition = getCaretPosition();
        
        Document document = getDocument();
        
        

        boolean underlineOn = false;

        
        // Load the text pane with styled text.
        try {
            document.remove( 0, document.getLength() );

            int regionStart = 0;
            int regionEnd = 0;
            
            for( int i=0; i < mText.length(); i++ ) {

                LinkMarker marker = (LinkMarker)( mLinkMarkerList.get( i ) );

                if( marker == null ) {
                    regionEnd++;
                    }
                else {
                    if( marker.mLinkStartEnd ) {
                        String region = mText.substring( regionStart,
                                                         regionEnd );
                        document.insertString( document.getLength(),
                                               region,
                                               getStyle( "regular" ) );

                        // output one underline char
                        document.insertString( document.getLength(),
                                               "" + mText.charAt( i ),
                                               getStyle( "underline" ) );
                        regionStart = i + 1;
                        regionEnd = i + 1;
                        }
                    else {
                        // output string for region so far
                        if( marker.mLinkEnd ) {
                            regionEnd++;
                            }
                    
                    
                        String region = mText.substring( regionStart,
                                                         regionEnd );
                        if( underlineOn ) {
                            document.insertString( document.getLength(),
                                                   region,
                                                   getStyle( "underline" ) );
                            }
                        else {
                            document.insertString( document.getLength(),
                                                   region,
                                                   getStyle( "regular" ) );
                            }
                    
                        regionStart = regionEnd;
                        regionEnd = regionStart;

                        if( !marker.mLinkEnd ) {
                            underlineOn = true;
                            regionEnd++;
                            }
                        else {
                            underlineOn = false;
                            }
                        }
                    }
                }
            if( regionStart < mText.length() &&
                regionEnd < mText.length() + 1 ) {

                // output string for remaining region
                String region = mText.substring( regionStart,
                                                 regionEnd );
                if( underlineOn ) {
                    document.insertString( document.getLength(),
                                           region,
                                           getStyle( "underline" ) );
                    }
                else {
                    document.insertString( document.getLength(),
                                           region,
                                           getStyle( "regular" ) );
                    }
                }
            }
        catch( BadLocationException inBLE ) {
            System.err.println( "Could not update document." );
            }

        setCaretPosition( caretPosition );
        
        mIgnoreCaret[0] = false;
        }
    


    protected class TextChangeListener implements CaretListener {

        public void caretUpdate( CaretEvent inEvent ) {
            if( mIgnoreCaret[0] ) {
                return;
                }

            boolean needsUpdate = false;
            
            String newText = getText();

            int oldLength = mText.length();
            int newLength = newText.length();

            final int caretPosition = getCaretPosition();
            
            if( newLength != oldLength ) {
                int shortLength = Math.min( newLength, oldLength );
                
                int indexDiff = -1;
                

                if( newLength < oldLength ) {
                    // char deleted
                    indexDiff = caretPosition;

                    LinkMarker marker =
                        (LinkMarker)( mLinkMarkerList.get( indexDiff ) );

                    if( marker != null ) {
                        if( marker.mLinkEnd ) {
                            // instead, delete the marker previous
                            // to this, if not the start marker

                            // indexDiff > 0 if we have an end marker
                            
                            LinkMarker previousMarker =
                                (LinkMarker)(
                                    mLinkMarkerList.get( indexDiff - 1 ) );
                            if( previousMarker == null ) {
                                mLinkMarkerList.remove( indexDiff - 1 );
                                }
                            else {
                                // previous is our matching start marker
                                
                                // convert previous into startEnd
                                previousMarker.mLinkStartEnd = true;
                                previousMarker.mLinkEnd = false;
                                // remove this marker
                                mLinkMarkerList.remove( indexDiff );
                                }
                            }
                        else if( marker.mLinkStartEnd ) {
                            // simply delete it
                            mLinkMarkerList.remove( indexDiff );
                            }
                        else {
                            // start marker
                            // push it onto next marker spot
                            mLinkMarkerList.remove( indexDiff );

                            // this is next spot, since we just removed
                            LinkMarker nextMarker =
                                (LinkMarker)(
                                    mLinkMarkerList.get( indexDiff ) );
                            if( nextMarker != null ) {
                                // push a startEnd marker onto next spot
                                marker.mLinkStartEnd = true;
                                }
                            mLinkMarkerList.set( indexDiff, marker );
                            }
                        needsUpdate = true;
                        }
                    else {
                        // simply remove a null marker
                        mLinkMarkerList.remove( indexDiff );
                        }
                    }
                else if( newLength > oldLength ) {
                    // char inserted
                    indexDiff = caretPosition - 1;

                    // if previous or next is part of a linked region, extend
                    // the region
                    LinkMarker previousMarker = null;
                    if( mLinkMarkerList.size() > 0 &&
                        indexDiff > 0 ) {
                        previousMarker =
                            (LinkMarker)(
                                mLinkMarkerList.get( indexDiff - 1 ) );
                        }

                    LinkMarker nextMarker = null;
                    if( mLinkMarkerList.size() > indexDiff ) {
                        nextMarker =
                            (LinkMarker)( mLinkMarkerList.get( indexDiff ) );
                        }
                    
                    if( previousMarker != null ) {
                        if( previousMarker.mLinkEnd ) {
                            // push end marker forward by one
                            mLinkMarkerList.add( indexDiff - 1, null );
                            needsUpdate = true;
                            }
                        else if( previousMarker.mLinkStartEnd ) {
                            // turn previous into a start marker
                            previousMarker.mLinkStartEnd = false;

                            // insert an end marker
                            LinkMarker marker = new LinkMarker();
                            marker.mLinkEnd = true;
                            mLinkMarkerList.add( indexDiff, marker );
                            needsUpdate = true;
                            }
                        else {
                            // a start marker... insert a null after it
                            mLinkMarkerList.add( indexDiff, null );
                            }
                            
                        }
                    else if( nextMarker != null ) {
                        if( nextMarker.mLinkEnd ) {
                            // an end marker... insert a null before it
                            mLinkMarkerList.add( indexDiff, null );
                            }
                        else if( nextMarker.mLinkStartEnd ) {
                            // insert a start marker
                            LinkMarker marker = new LinkMarker();
                            marker.mLinkAnchor = nextMarker.mLinkAnchor;
                            mLinkMarkerList.add( indexDiff, marker );
                            
                            // turn next into an end marker
                            nextMarker.mLinkAnchor = null;
                            nextMarker.mLinkStartEnd = false;
                            nextMarker.mLinkEnd = true;
                            needsUpdate = true;
                            }
                        else {
                            // next is a start marker
                            
                            // insert a null marker after it
                            mLinkMarkerList.add( indexDiff + 1, null );
                            needsUpdate = true;
                            }
                        }
                    else {
                        // we're in the middle of a link
                        // or outside a link completely
                        mLinkMarkerList.add( indexDiff, null );
                        }
                    }

                
                mText = newText;


                if( needsUpdate ) {
                    SwingUtilities.invokeLater(
                        new Runnable() {
                                public void run() {
                                    //mIgnoreCaret[0] = true;
                                    updateDocument();
                                    //setCaretPosition( caretPosition );
                                    //mIgnoreCaret[0] = false;
                                    }
                                } );
                    }
                
                
                }
            
            }

        }
    

    }

