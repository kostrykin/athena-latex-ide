using Granite.Widgets;


public class MainWindow : Gtk.Window
{

    private Gtk.Stack stack = new Gtk.Stack();
    private Editor editor   = new Editor();

    public MainWindow( Athena app )
    {
        this.title = app.program_name;
        this.set_default_size( 1000, 500 );
        this.window_position = Gtk.WindowPosition.CENTER;
        this.set_hide_titlebar_when_maximized( false );

        this.setup_headerbar( app );
        this.setup_welcome_screen( app );
        this.setup_editor();

        var hbox = new Gtk.Box( Gtk.Orientation.HORIZONTAL, 0 );
        hbox.pack_start( stack );
        this.add( hbox );
    }

    private void setup_headerbar( Athena app )
    {
        var headerbar = new Gtk.HeaderBar();
        headerbar.title = "Intermediate Session";
        headerbar.show_close_button = true;
        headerbar.get_style_context().add_class( "primary-toolbar" );
        headerbar.pack_end( app.create_appmenu( new Gtk.Menu() ) );
        this.set_titlebar( headerbar );
    }

    private void setup_welcome_screen( Athena app )
    {
        var welcome = new Welcome( app.program_name, "documents & presentations as they are meant to be" );

        welcome.append( "document-page-setup", "Start a Project", "Follow a few guided steps to create a new project.");
        welcome.append( "document-new", "New .TeX File", "Start with an empty LaTeX file.");
        welcome.append( "document-open", "Open", "Continue from a previously saved file or session." );

        stack.add_named( welcome, "welcome" );

        var self = this;
        welcome.activated.connect( ( index ) =>
            {
                switch( index )
                {

                case 0:
                    self.start_project();
                    break;

                case 1:
                    self.open_new_file();
                    break;

                case 2:
                    self.open_previous();
                    break;

                }
            }
        );
    }

    private void setup_editor()
    {
        stack.add_named( editor, "editor" );
        editor.file_closed.connect( () =>
            {
                if( editor.files_count == 0 )
                {
                    stack.set_visible_child_name( "welcome" );
                }
            }
        );
    }

    private void start_project()
    {
    }

    private void open_new_file()
    {
        editor.open_new_file();
        stack.set_visible_child_name( "editor" );
    }

    private void open_previous()
    {
        FileDialog.choose_readable_file_and( ( path ) =>
            {
                if( path != null )
                {
                    editor.open_file_from( path );
                    stack.set_visible_child_name( "editor" );
                }
            }
        );
    }

}
