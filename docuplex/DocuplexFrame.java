/*
 * Modificaton History
 *
 * 2002-February-27   Jason Rohrer
 * Created.
 *
 * 2002-February-28   Jason Rohrer
 * Added versioning support. 
 */



import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JLabel;
import javax.swing.JTextArea;
import javax.swing.JScrollPane;
import javax.swing.JCheckBox;
import javax.swing.JButton;
import javax.swing.JList;


import javax.swing.BoxLayout;

import java.awt.FlowLayout;
import java.awt.BorderLayout;


import java.awt.Insets;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;


import java.awt.event.TextEvent;
import java.awt.event.TextListener;


import javax.swing.event.CaretEvent;
import javax.swing.event.CaretListener;

import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import Content;


import java.util.Vector;
import java.util.ArrayList;


import java.io.FileOutputStream;
import java.io.PrintStream;




/**
 * The main display frame, with main method, for Docuplex.
 *
 * @author Jason Rohrer
 */
public class DocuplexFrame extends JFrame {


    public static void main( String inArgs[] ) {
        new DocuplexFrame();
        }
    


    protected JTextArea mViewTextArea = new JTextArea( 50, 0 );
    protected JTextArea mRegionListTextArea = new JTextArea( 50, 0);
    protected JTextArea mContentTextArea = new JTextArea( 50, 0);


    protected String mLastViewText = mViewTextArea.getText();

    

    protected Content mContent = new Content();
    protected View mView = new View( mContent );
    

    protected JCheckBox mRegionListActiveCheckbox
        = new JCheckBox( "Active", true );
    protected JCheckBox mContentActiveCheckbox
        = new JCheckBox( "Active", true );


    protected JButton mViewCopyButton = new JButton( "Copy" );
    protected JButton mViewPasteButton = new JButton( "Paste" );
    protected JButton mViewExportButton = new JButton( "Export Text" );

    
    protected JButton mContentCopyButton = new JButton( "Copy" );


    protected JButton mNewVersionButton = new JButton( "New" );

    

    
    
    protected Vector mVersionVector = new Vector();

    protected String mCurrentVersionString = "Current";
    protected ArrayList mCurrentVersion = null;
    
    
    protected JList mVersionList;

    protected int mVersionCount = 1;
    
    
    protected boolean mIngoreCaret = false;
    protected boolean mIgnoreListChange = false;
    
    
    /**
     * constructs a DocuplexFrame and displays it.
     */
    public DocuplexFrame() {
        super( "Docuplex" );

        mVersionVector.add( mCurrentVersionString );
        // a blank version
        mVersionVector.add( new VersionWrapper( "v0", new ArrayList() ) );
        
        mVersionList = new JList( mVersionVector );
        mVersionList.setVisibleRowCount( 10 );
        mVersionList.setSelectedIndex( 1 );

        getContentPane().setLayout( new BorderLayout() );
        JPanel centerPanel = new JPanel();

        getContentPane().add( centerPanel, BorderLayout.CENTER );

        
        
        
        JScrollPane versionListScrollPane = new JScrollPane( mVersionList );
        
        
        centerPanel.setLayout( new BoxLayout( centerPanel,
                                                    BoxLayout.Y_AXIS ) );


        JPanel viewPanel = new JPanel();

        viewPanel.setLayout( new BoxLayout( viewPanel,
                                            BoxLayout.Y_AXIS ) );

        JPanel regionListPanel = new JPanel();

        regionListPanel.setLayout( new BoxLayout( regionListPanel,
                                            BoxLayout.Y_AXIS ) );

        
        

        JPanel contentPanel = new JPanel();

        contentPanel.setLayout( new BoxLayout( contentPanel,
                                               BoxLayout.Y_AXIS ) );


        centerPanel.add( viewPanel );
        centerPanel.add( regionListPanel );
        centerPanel.add( contentPanel );


        JPanel versionPanel = new JPanel(
            new FlowLayout( FlowLayout.CENTER ) );

        JPanel versionSubPanel = new JPanel();
        versionSubPanel.setLayout( new BoxLayout( versionSubPanel,
                                               BoxLayout.Y_AXIS ) );
        JPanel versionLabelPanel = new JPanel(
            new FlowLayout( FlowLayout.LEFT ) );
        versionLabelPanel.add( new JLabel( "Version:" ) );
        versionSubPanel.add( versionLabelPanel );
        versionSubPanel.add( versionListScrollPane );
        versionSubPanel.add( mNewVersionButton );

        versionPanel.add( versionSubPanel );
        
        getContentPane().add( versionPanel, BorderLayout.WEST );


        JPanel viewLabelPanel =
            new JPanel( new FlowLayout( FlowLayout.LEFT ) );
        
        viewLabelPanel.add( new JLabel( "View:" ) );

        
        JPanel viewCopyPanel =
            new JPanel( new FlowLayout( FlowLayout.RIGHT ) );
        viewCopyPanel.add( mViewExportButton );
        viewCopyPanel.add( mViewCopyButton );
        viewCopyPanel.add( mViewPasteButton );
        
        
        JPanel viewTopPanel = new JPanel();
        viewTopPanel.setLayout( new BoxLayout( viewTopPanel,
                                               BoxLayout.X_AXIS ) );
        viewTopPanel.add( viewLabelPanel );
        viewTopPanel.add( viewCopyPanel );
        
        viewPanel.add( viewTopPanel );
        



        JPanel regionListLabelPanel =
            new JPanel( new FlowLayout( FlowLayout.LEFT ) );
        
        regionListLabelPanel.add( new JLabel( "Region List:" ) );


        JPanel regionListActiveControlPanel =
            new JPanel( new FlowLayout( FlowLayout.RIGHT ) );
        regionListActiveControlPanel.add( mRegionListActiveCheckbox );

        
        JPanel regionListTopPanel = new JPanel();
        regionListTopPanel.setLayout( new BoxLayout( regionListTopPanel,
                                               BoxLayout.X_AXIS ) );
        regionListTopPanel.add( regionListLabelPanel );
        regionListTopPanel.add( regionListActiveControlPanel );
        
        regionListPanel.add( regionListTopPanel );

        



        JPanel contentLabelPanel =
            new JPanel( new FlowLayout( FlowLayout.LEFT ) );
        
        contentLabelPanel.add( new JLabel( "Content:" ) );


        JPanel contentCopyPanel =
            new JPanel( new FlowLayout( FlowLayout.CENTER ) );
        contentCopyPanel.add( mContentCopyButton );
        
        JPanel contentActiveControlPanel =
            new JPanel( new FlowLayout( FlowLayout.RIGHT ) );
        contentActiveControlPanel.add( mContentActiveCheckbox );

        
        JPanel contentTopPanel = new JPanel();
        contentTopPanel.setLayout( new BoxLayout( contentTopPanel,
                                               BoxLayout.X_AXIS ) );
        contentTopPanel.add( contentLabelPanel );
        contentTopPanel.add( contentCopyPanel );
        contentTopPanel.add( contentActiveControlPanel );
        
        contentPanel.add( contentTopPanel );

        


        JScrollPane viewTextAreaScrollPane =
            new JScrollPane(
                mViewTextArea,
                JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
                JScrollPane.HORIZONTAL_SCROLLBAR_NEVER );
        
        viewPanel.add( viewTextAreaScrollPane );

        
        JScrollPane regionListTextAreaScrollPane =
            new JScrollPane(
                mRegionListTextArea,
                JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
                JScrollPane.HORIZONTAL_SCROLLBAR_NEVER );
        
        regionListPanel.add( regionListTextAreaScrollPane );

        
        JScrollPane contentTextAreaScrollPane =
            new JScrollPane(
                mContentTextArea,
                JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED,
                JScrollPane.HORIZONTAL_SCROLLBAR_NEVER );
        
        contentPanel.add( contentTextAreaScrollPane );
        
        mContentTextArea.setEditable( false );
        mContentTextArea.setLineWrap( true );

        mRegionListTextArea.setEditable( false );
        mRegionListTextArea.setLineWrap( true );

        mViewTextArea.addCaretListener( new ViewTextListener() );
        mViewTextArea.setLineWrap( true );

        CheckActionListener checkListener = new CheckActionListener();
        
        mRegionListActiveCheckbox.addActionListener( checkListener );
        mContentActiveCheckbox.addActionListener( checkListener );


        ButtonActionListener buttonListener = new ButtonActionListener();
        mViewExportButton.addActionListener( buttonListener );
        mViewCopyButton.addActionListener( buttonListener );
        mViewPasteButton.addActionListener( buttonListener );
        mContentCopyButton.addActionListener( buttonListener );
        mNewVersionButton.addActionListener( buttonListener );

        ListListener listListener = new ListListener();
        mVersionList.addListSelectionListener( listListener ); 
        
        
        mViewTextArea.setMargin( new Insets( 20, 20, 20, 20 ) );

        mRegionListTextArea.setMargin( new Insets( 5, 5, 5, 5 ) );
        mContentTextArea.setMargin( new Insets( 5, 5, 5, 5 ) );

        
        setSize( 500, 600 );

        setVisible( true );
        }


    
    protected class CheckActionListener implements ActionListener {

        public void actionPerformed( ActionEvent inEvent ) {
            if( inEvent.getSource() == mRegionListActiveCheckbox ) {
                mRegionListTextArea.setText( mView.getRegionList() );
                }
            else if( inEvent.getSource() == mContentActiveCheckbox ) {
                mContentTextArea.setText( mContent.getContentString() );
                mContentCopyButton.setEnabled(
                    mContentActiveCheckbox.isSelected() );
                }
            }
        }


    protected class ListListener implements ListSelectionListener {
        
        public void valueChanged( ListSelectionEvent inEvent ) {

            if( mIgnoreListChange ) {
                return;
                }
            
            Object selected = mVersionList.getSelectedValue();

            if( selected != null ) {

                if( selected == mCurrentVersionString ) {
                    if( mCurrentVersion != null ) {
                        mView.setVersion( mCurrentVersion );
                        mCurrentVersion = null;
                        }
                    }
                else {
                    VersionWrapper wrapper = (VersionWrapper)selected;

                    if( mCurrentVersion == null ) {
                        mCurrentVersion = mView.getCurrentVersion();
                        }
                    
                    mView.setVersion( wrapper.mVersion );                    
                    }

                boolean oldIgnore = mIngoreCaret;
                mIngoreCaret = true;                
                
                mLastViewText = mView.getViewText();
                mViewTextArea.setText( mLastViewText );
                
                if( mRegionListActiveCheckbox.isSelected() ) {
                    mRegionListTextArea.setText( mView.getRegionList() );
                    }
                
                mIngoreCaret = oldIgnore;
                                    

                }
            
            }
        
        }

    
    protected class ButtonActionListener implements ActionListener {

        public void actionPerformed( ActionEvent inEvent ) {
            if( inEvent.getSource() == mViewExportButton ) {
                try {
                    PrintStream pStream =
                        new PrintStream(
                            new FileOutputStream( "export.txt" ) );

                    pStream.print( mView.getViewText() );
                    pStream.flush();
                    pStream.close();

                    System.out.println( "Exported to file \"export.txt\"." );
                    }
                catch( java.io.IOException inException ) {
                    System.out.println( "Export failed." );
                    }
                }
            else if( inEvent.getSource() == mViewCopyButton ) {
                int start = mViewTextArea.getSelectionStart();
                int end = mViewTextArea.getSelectionEnd();

                if( end > mViewTextArea.getText().length() ) {
                    end = end - 1;
                    }
                                
                if( start < end ) {
                    mView.viewCopy( start, end - 1 );
                    }
                }
            else if( inEvent.getSource() == mContentCopyButton ) {
                int start = mContentTextArea.getSelectionStart();
                int end = mContentTextArea.getSelectionEnd();

                if( end > mContentTextArea.getText().length() ) {
                    end = end - 1;
                    }
                                
                if( start < end ) {
                    mView.contentCopy( start, end - 1 );
                    }
                }
            else if( inEvent.getSource() == mViewPasteButton ) {
                boolean oldIgnore = mIngoreCaret;
                mIngoreCaret = true;
                
                int oldPos = mViewTextArea.getCaretPosition();
                int pastePos = oldPos;
                //if( pastePos < 0 ) {
                //    pastePos = 0;
                //    }
                mView.viewPaste( pastePos );

                mLastViewText = mView.getViewText();
                mViewTextArea.setText( mLastViewText );

                mViewTextArea.setCaretPosition( oldPos );

                if( mRegionListActiveCheckbox.isSelected() ) {
                    mRegionListTextArea.setText( mView.getRegionList() );
                    }

                mIngoreCaret = oldIgnore;

                mIgnoreListChange = true;
                mCurrentVersion = null;
                mVersionList.setSelectedIndex( 0 );
                mIgnoreListChange = false;
                }
            
            else if( inEvent.getSource() == mNewVersionButton ) {
                
                mVersionVector.add(
                    1,
                    new VersionWrapper(
                        "v" + mVersionCount,
                        mView.getCurrentVersion() ) );

                mVersionList.setListData( mVersionVector );
                
                mVersionCount++;

                mIgnoreListChange = true;
                mCurrentVersion = null;
                mVersionList.setSelectedIndex( 1 );
                mIgnoreListChange = false;

                }
            }
        }
    
    

    
    protected class ViewTextListener implements CaretListener {

        public void caretUpdate( CaretEvent inEvent ) {
            if( mIngoreCaret ) {
                return;
                }
            String newText = mViewTextArea.getText();

            int oldLength = mLastViewText.length();
            int newLength = newText.length();
            
            if( newLength != oldLength ) {
                int shortLength = Math.min( newLength, oldLength );
                
                int indexDiff = -1;
                

                if( newLength < oldLength ) {
                    // char deleted
                    indexDiff = mViewTextArea.getCaretPosition();

                    mView.deleteCharacter( indexDiff );

                    if( mRegionListActiveCheckbox.isSelected() ) {
                        mRegionListTextArea.setText( mView.getRegionList() );
                        }
                    }
                else if( newLength > oldLength ) {
                    // char inserted
                    indexDiff = mViewTextArea.getCaretPosition() - 1;

                    char newChar = newText.charAt( indexDiff );
                    
                    mView.addCharacter( newChar, indexDiff  );

                    if( mRegionListActiveCheckbox.isSelected() ) {
                        mRegionListTextArea.setText( mView.getRegionList() );
                        }
                    
                    char [] tempArray = new char[ 1 ];
                    tempArray[0] = newChar;

                    if( mContentActiveCheckbox.isSelected() ) {
                        mContentTextArea.append( new String( tempArray ) );
                        }
                    }

                mLastViewText = newText;

                mIgnoreListChange = true;
                mCurrentVersion = null;
                mVersionList.setSelectedIndex( 0 );
                mIgnoreListChange = false;
                }
            
            }

        }



    protected class VersionWrapper {

        public ArrayList mVersion;

        public String mName;


        
        public VersionWrapper( String inName, ArrayList inList ) {
            mName = inName;

            mVersion = inList;
            }


        
        public String toString() {
            return mName;
            }


        
        }


    
    }


