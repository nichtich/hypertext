/**
 * Modification History
 *
 * 2002-May-14   Jason Rohrer
 * Created.
 *
 * 2002-Jun-4   Jason Rohrer
 * Added output of header and footer.
 */



package hyperlit;

import hyperlit.LinkTextArea;


import javax.swing.JFrame;
import javax.swing.JMenuBar;
import javax.swing.JMenu;
import javax.swing.JMenuItem;
import javax.swing.JLabel;
import javax.swing.JPanel;

import javax.swing.JScrollPane;
import javax.swing.JList;


import javax.swing.BoxLayout;
import java.awt.BorderLayout;
import java.awt.FlowLayout;


import javax.swing.KeyStroke;

import java.awt.event.KeyEvent;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;


import java.util.Vector;

import java.io.ObjectOutputStream;
import java.io.ObjectInputStream;

import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.File;
import java.io.PrintStream;



/**
 * The main frame for hyperlit.
 *
 * @author Jason Rohrer
 */
class HyperlitFrame extends JFrame {

    protected LinkTextArea mTextArea = new LinkTextArea();

    protected JMenuBar mMenuBar = new JMenuBar();

    protected JMenu mOperationsMenu = new JMenu( "operations" );


    protected JMenuItem mNewLexiaItem = new JMenuItem( "new lexia" );

    protected JMenuItem mLinkToExistingItem =
        new JMenuItem( "link to existing" );

    protected JMenuItem mClearLinkItem = new JMenuItem( "clear link" );

    
    protected JMenuItem mTraverseLinkItem = new JMenuItem( "traverse link" );

    protected JMenuItem mPreviousLexiaItem = new JMenuItem( "previous lexia" );
    protected JMenuItem mNextLexiaItem = new JMenuItem( "next lexia" );
    protected JMenuItem mDeleteLexiaItem = new JMenuItem( "delete lexia" );


    protected JMenuItem mSaveLexiaItem = new JMenuItem( "save all lexia" );
    protected JMenuItem mOutputHTMLItem = new JMenuItem( "output html" );

    
    protected JMenuItem mQuitItem = new JMenuItem( "quit" );


    JLabel mStatusLabel = new JLabel( "status:" );
    JLabel mStatusValueLabel = new JLabel( "" );

    

    JList mLexiaList = new JList();

    Vector mLexiaVector = new Vector();

    int mCurrentLexiaIndex;


    String mLexiaFileName;
    
    

    public HyperlitFrame( String inLexiaFileName ) {
        super( "hyperlit" );
        
        mLexiaFileName = inLexiaFileName;

        
        mSaveLexiaItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_S,
                                    java.awt.Event.CTRL_MASK ) );
        
        mNewLexiaItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_N,
                                    java.awt.Event.CTRL_MASK ) );

        mTraverseLinkItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_T,
                                    java.awt.Event.CTRL_MASK ) );

        mLinkToExistingItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_L,
                                    java.awt.Event.CTRL_MASK ) );

        mClearLinkItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_U,
                                    java.awt.Event.CTRL_MASK ) );

        // no modifier
        mPreviousLexiaItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_PAGE_UP,
                                    java.awt.Event.CTRL_MASK ) );
        mNextLexiaItem.setAccelerator(
            KeyStroke.getKeyStroke( KeyEvent.VK_PAGE_DOWN,
                                    java.awt.Event.CTRL_MASK ) );

        
        MenuActionListener menuListener = new MenuActionListener();
        mNewLexiaItem.addActionListener( menuListener );
        mSaveLexiaItem.addActionListener( menuListener );
        mTraverseLinkItem.addActionListener( menuListener );
        mLinkToExistingItem.addActionListener( menuListener );
        mClearLinkItem.addActionListener( menuListener );
        mPreviousLexiaItem.addActionListener( menuListener );
        mNextLexiaItem.addActionListener( menuListener );
        mDeleteLexiaItem.addActionListener( menuListener );
        mOutputHTMLItem.addActionListener( menuListener );
        mQuitItem.addActionListener( menuListener );

        
        mOperationsMenu.add( mNewLexiaItem );
        mOperationsMenu.add( mSaveLexiaItem );
        mOperationsMenu.add( mTraverseLinkItem );
        mOperationsMenu.add( mLinkToExistingItem );
        mOperationsMenu.add( mClearLinkItem );

        mOperationsMenu.addSeparator();
        mOperationsMenu.add( mPreviousLexiaItem );
        mOperationsMenu.add( mNextLexiaItem );
        mOperationsMenu.add( mDeleteLexiaItem );

        mOperationsMenu.addSeparator();
        mOperationsMenu.add( mSaveLexiaItem );
        mOperationsMenu.add( mOutputHTMLItem );
        
        
        mOperationsMenu.addSeparator();
        mOperationsMenu.add( mQuitItem );
        
        
        
        mMenuBar.add( mOperationsMenu );

        setJMenuBar( mMenuBar );


        getContentPane().setLayout( new BorderLayout() );

        getContentPane().add( mTextArea, BorderLayout.CENTER );
        

        Lexia firstLexia = mTextArea.getLexia();
        mLexiaVector.add( firstLexia );
        mCurrentLexiaIndex = 0;

        try {
            File lexiaFile = new File( mLexiaFileName );
            if( lexiaFile.exists() ) {
                ObjectInputStream objStream =
                    new ObjectInputStream( new FileInputStream( lexiaFile ) );

                Integer count = (Integer)( objStream.readObject() );
                Lexia.setLexiaCount( count.intValue() );
                
                mLexiaVector = (Vector)( objStream.readObject() );
                objStream.close();

                if( mLexiaVector.size() > 0 ) {
                    mTextArea.setLexia( (Lexia)( mLexiaVector.get( 0 ) ) );
                    }
                else {
                    mLexiaVector.add( firstLexia );
                    }
                }
            }
        catch( Exception inException ) {
            System.out.println( "Failed to read from file:  " +
                                mLexiaFileName );
            }
            
        
        
        mLexiaList = new JList( mLexiaVector );
        mLexiaList.setSelectedIndex( 0 );
        
        JScrollPane lexiaListScrollPane = new JScrollPane( mLexiaList );
        
        getContentPane().add( lexiaListScrollPane, BorderLayout.WEST );


        ListListener listListener = new ListListener();
        mLexiaList.addListSelectionListener( listListener );


        JPanel statusPanel= new JPanel( new FlowLayout( FlowLayout.LEFT ) );
        getContentPane().add( statusPanel, BorderLayout.SOUTH );

        statusPanel.add( mStatusLabel );
        statusPanel.add( mStatusValueLabel );
        
        
        setSize( 400, 500 );

        setVisible( true );
        }



    public static void main( String inArgs[] ) {
        if( inArgs.length != 1 ) {
            System.out.println( "must input a file name for lexia storage." );
            System.out.println( "example:" );
            System.out.println( "java hyperlit.HyperlitFrame temp.lex" );
            }
        else {
            new HyperlitFrame( inArgs[0] );
            }
        }


    boolean mLinkToExistingInProgress = false;
    int mLinkToStartLexiaIndex;
    TextRegion mLinkToStartLexiaRegion;

    

    protected class MenuActionListener implements ActionListener {

        public void actionPerformed( ActionEvent inEvent ) {

            if( inEvent.getSource() == mNewLexiaItem ) {
                Lexia lexia = new Lexia();
                
                // add link to current lexia
                TextRegion region = mTextArea.getCurrentCaretWord();
                mTextArea.addLinkToRegion( region, lexia.mName );

                // save current lexia to vector
                mLexiaVector.set( mCurrentLexiaIndex, mTextArea.getLexia() );

                // add new lexia to vector
                mLexiaVector.add( lexia );

                mCurrentLexiaIndex = mLexiaVector.indexOf( lexia );

                mTextArea.setLexia( lexia );

                mIgnoreListChange = true;
                mLexiaList.setListData( mLexiaVector );
                mLexiaList.setSelectedIndex( mLexiaVector.size() );
                mIgnoreListChange = false;
                }
            else if( inEvent.getSource() == mTraverseLinkItem ) {
                TextRegion region = mTextArea.getCurrentCaretWord();

                String anchor = mTextArea.getLinkAnchor( region.getStart() );
                if( anchor != null ) {

                    int numLexia = mLexiaVector.size();
                    boolean found = false;
                    for( int i=0; i<numLexia && !found; i++ ) {
                        Lexia lexia = (Lexia)( mLexiaVector.get( i ) );
                        if( lexia.mName.equals( anchor ) ) {
                            found = true;
                            // let list selection handler take care of rest
                            mLexiaList.setSelectedIndex( i );
                            }
                        }
                    }
                }
            else if( inEvent.getSource() == mLinkToExistingItem ) {
                if( ! mLinkToExistingInProgress ) {
                    // source of link chosen
                    mLinkToStartLexiaRegion = mTextArea.getCurrentCaretWord();
                    
                    mLinkToExistingInProgress = true;
                    mLexiaVector.set( mCurrentLexiaIndex,
                                      mTextArea.getLexia() );
                    
                    mLinkToStartLexiaIndex = mCurrentLexiaIndex;
                    mStatusValueLabel.setText( "ctl-L again to pick target" );
                    //mStatusValueLabel.repaint();
                    }
                else {
                    // target of link chosen

                    Lexia target = mTextArea.getLexia();

                    mIgnoreListChange = true;
                    mLexiaList.setSelectedIndex( mLinkToStartLexiaIndex );
                    mIgnoreListChange = false;

                    Lexia source = (Lexia)(
                        mLexiaVector.get( mLinkToStartLexiaIndex ) );
                    
                    mTextArea.setLexia( source );
                    
                    mTextArea.addLinkToRegion( mLinkToStartLexiaRegion,
                                               target.mName );

                    mLinkToExistingInProgress = false;
                    mStatusValueLabel.setText( "" );
                    
                    mCurrentLexiaIndex = mLinkToStartLexiaIndex;
                    //mStatusValueLabel.repaint();
                    }
                
                }
            else if( inEvent.getSource() == mClearLinkItem ) {
                TextRegion region = mTextArea.getCurrentCaretWord();
                mTextArea.clearLinksFromRegion( region );
                }
            else if( inEvent.getSource() == mPreviousLexiaItem ) {
                
                int newIndex = mCurrentLexiaIndex - 1;
                if( newIndex < 0 ) {
                    newIndex += mLexiaVector.size();
                    }
                mLexiaList.setSelectedIndex( newIndex );
                }
            else if( inEvent.getSource() == mNextLexiaItem ) {
                
                int newIndex = mCurrentLexiaIndex + 1;
                if( newIndex >= mLexiaVector.size() ) {
                    newIndex -= mLexiaVector.size();
                    }
                mLexiaList.setSelectedIndex( newIndex );
                }
            else if( inEvent.getSource() == mDeleteLexiaItem ) {
                // only allow deletes if we have more than one lexia
                if( mLexiaVector.size() > 1 ) {
                    int newCurrentIndex = mCurrentLexiaIndex;
                    int replacementIndex = mCurrentLexiaIndex + 1;
                    if( replacementIndex > mLexiaVector.size() - 1 ) {
                        replacementIndex = mCurrentLexiaIndex - 1;
                        newCurrentIndex = mCurrentLexiaIndex - 1;
                        }
                    Lexia replacementLexia =
                        (Lexia)( mLexiaVector.get( replacementIndex ) );
                    mTextArea.setLexia( replacementLexia );

                    mLexiaVector.remove( mCurrentLexiaIndex );

                    mCurrentLexiaIndex = newCurrentIndex;
                    }
                }
            else if( inEvent.getSource() == mSaveLexiaItem ) {

                try {
                    File lexiaFile = new File( mLexiaFileName );
                    
                    ObjectOutputStream objStream =
                        new ObjectOutputStream(
                            new FileOutputStream( lexiaFile ) );
                    
                    mLexiaVector.set( mCurrentLexiaIndex,
                                      mTextArea.getLexia() );

                    objStream.writeObject(
                        new Integer( Lexia.getLexiaCount() ) ); 
                    
                    objStream.writeObject( mLexiaVector );
                    objStream.close();
                    
                    }
                catch( Exception inException ) {
                    System.out.println( "Failed to write to file:  " +
                                        mLexiaFileName );
                    inException.printStackTrace();
                    }
                }
            else if( inEvent.getSource() == mOutputHTMLItem ) {
                try {
                    String dirName = mLexiaFileName + ".dir";
                    File dirFile = new File( dirName );
                    dirFile.mkdir();

                    int numLexia = mLexiaVector.size();
                    for( int i=0; i<numLexia; i++ ) {
                        Lexia lexia = (Lexia)( mLexiaVector.get( i ) );
                        
                        String fileName = lexia.mName + ".shtml";

                        File lexiaFile = new File( dirFile, fileName );
                        FileOutputStream outStream =
                            new FileOutputStream( lexiaFile );

                        lexia.writeHTML( outStream );
                        outStream.close();
                        }

                    // write a header file
                    File headerFile = new File( dirFile, "header.html" );
                    FileOutputStream headerStream =
                        new FileOutputStream( headerFile );
                    PrintStream headerPrintStream =
                        new PrintStream( headerStream );
                    headerPrintStream.print(
                        "<HTML>\n" +
                        "<HEAD>\n" +
                        "<TITLE>" + mLexiaFileName + "</TITLE>\n" +
                        "</HEAD>\n\n" +
                        "<BODY BGCOLOR=whiteTEXT=black " +
                        "LINK=black VLINK=black ALINK=gray>\n" +
                        "<BR>\n" +
                        "<BR>\n" +
                        "<CENTER>\n" +
                        "<TABLE BORDER=0 WIDTH=50%>\n" +
                        "<TR>\n" +
                        "<TD>\n" );
                    headerStream.close();

                    // write a footer file
                    File footerFile = new File( dirFile, "footer.html" );
                    FileOutputStream footerStream =
                        new FileOutputStream( footerFile );
                    PrintStream footerPrintStream =
                        new PrintStream( footerStream );
                    footerPrintStream.print(

                        "</TD>\n" +
                        "</TR>\n" +
                        "</TABLE>\n" +
                        
                        "</BODY>\n" +
                        
                        "</HTML>\n" );
                    footerStream.close();

                    }
                catch( Exception inException ) {
                    System.out.println( "Failed to output HTML." );
                    inException.printStackTrace();
                    }
                }
            else if( inEvent.getSource() == mQuitItem ) {
                System.exit( 0 );
                }
            }
        }


    
    protected boolean mIgnoreListChange = false;

    
    
    protected class ListListener implements ListSelectionListener {
        
        public void valueChanged( ListSelectionEvent inEvent ) {
            
            if( mIgnoreListChange ) {
                return;
                }
            
            Object selected = mLexiaList.getSelectedValue();
            int selectedIndex = mLexiaList.getSelectedIndex();
            
            if( selected != null ) {

                Lexia currentLexia = mTextArea.getLexia();
                mLexiaVector.set( mCurrentLexiaIndex, currentLexia );

                
                Lexia lexia = (Lexia)selected;

                mTextArea.setLexia( lexia );
                mCurrentLexiaIndex = selectedIndex;
                }
            
            }
        
        }

    
    }
