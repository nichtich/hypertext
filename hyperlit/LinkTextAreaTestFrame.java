/**
 * Modification History
 *
 * 2002-May-14   Jason Rohrer
 * Created.
 */



package hyperlit;

import hyperlit.LinkTextArea;


import javax.swing.JFrame;
import javax.swing.JTextArea;
import javax.swing.JTextPane;

import javax.swing.JButton;
import javax.swing.JLabel;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;


import javax.swing.text.Document;
import javax.swing.text.Style;
import javax.swing.text.StyleConstants;
import javax.swing.text.StyleContext;
import javax.swing.text.BadLocationException;

import javax.swing.BoxLayout;



/**
 * A frame for testing a LinkTextArea.
 *
 * @author Jason Rohrer
 */
class LinkTextAreaTestFrame extends JFrame {

    protected LinkTextArea mTextArea = new LinkTextArea();

    protected JButton mMakeLinkButton = new JButton( "make link" );
    protected JButton mClearLinkButton = new JButton( "clear link" );
    protected JButton mCheckLinkButton = new JButton( "check link" );
    protected JButton mPrintLexiaButton = new JButton( "print lexia" );

    protected JLabel mCheckLabel = new JLabel( "none" );
    
    protected int mLinkCounter = 0;
    

    
    /**
     * Constructs a frame and displays it.
     */
    public LinkTextAreaTestFrame() {
        super( "Test Frame" );

        getContentPane().setLayout( new BoxLayout( getContentPane(),
                                                   BoxLayout.Y_AXIS ) );

        getContentPane().add( mMakeLinkButton );
        getContentPane().add( mClearLinkButton );
        getContentPane().add( mCheckLinkButton );
        getContentPane().add( mCheckLabel );
        getContentPane().add( mPrintLexiaButton );

        
        mMakeLinkButton.addActionListener( new ButtonActionListener() );
        mClearLinkButton.addActionListener( new ButtonActionListener() );
        mCheckLinkButton.addActionListener( new ButtonActionListener() );
        mPrintLexiaButton.addActionListener( new ButtonActionListener() );

        getContentPane().add( mTextArea );

        setSize( 400, 500 );

        setVisible( true );
        }

    
    
    public static void main( String inArgs[] ) {
        new LinkTextAreaTestFrame();        
        }



    protected class ButtonActionListener implements ActionListener {

        public void actionPerformed( ActionEvent inEvent ) {
            if( inEvent.getSource() == mMakeLinkButton ) {
                TextRegion region = mTextArea.getCurrentCaretWord();
                
                mTextArea.addLinkToRegion(
                    region,
                    "" + mLinkCounter );

                mLinkCounter++;
                }
            else if( inEvent.getSource() == mClearLinkButton ) {
                TextRegion region = mTextArea.getCurrentCaretWord();
                mTextArea.clearLinksFromRegion( region );
                }
            else if( inEvent.getSource() == mCheckLinkButton ) {
                TextRegion region = mTextArea.getCurrentCaretWord();
                String anchor = mTextArea.getLinkAnchor( region.getStart() );
                if( anchor != null ) {
                    mCheckLabel.setText( anchor );
                    }
                else {
                    mCheckLabel.setText( "none" );
                    }
                }
            else if( inEvent.getSource() == mPrintLexiaButton ) {
                System.out.println( "Lexia as HTML:" );
                mTextArea.getLexia().writeHTML( System.out );
                System.out.println( );
                }
            }
        }

    
    }
