public class Athena : Granite.Application
{

    construct
    {
        flags          =  ApplicationFlags.HANDLES_OPEN;
        application_id = "org.kostrykin.athena-latex-ide";
        program_name   = "Athena";
        app_years      = "2016";
        
        build_version =  Utils.get_version();
        app_icon      = "athena-latex-ide";
        main_url      = "https://github.com/kostrykin/athena";
        bug_url       = "https://github.com/kostrykin/athena/issues";
        about_authors = {
            "Leonid Kostrykin <void@evoid.de>", null
        };

        about_comments     = "Streamlined LaTeX IDE";
        about_license      = "GNU GPL 3.0";
        about_license_type = Gtk.License.GPL_3_0;
    }

    public Settings settings { get; private set; }
    public static Athena instance { get; private set; }

    private weak MainWindow? window;
    private bool activated;

    public Athena()
    {
        Object();
        assert( _instance == null );
        instance = this;
        settings = new Settings();
    }

    private Gee.Deque< Gdk.Cursor > cursors = new Gee.ArrayQueue< Gdk.Cursor >();

    public void override_cursor( Gdk.Cursor cursor )
    {
        cursors.offer_head( cursor );
        change_cursor( cursor );
    }

    public void restore_cursor()
    {
        cursors.poll_head();
        Gdk.Cursor? cursor = cursors.peek_head();
        change_cursor( cursor );
    }

    public signal void change_cursor( Gdk.Cursor? new_cursor );

    public override void startup()
    {
        base.startup();
        activated = false;

        var css    = new Gtk.CssProvider();
        var screen = Gdk.Screen.get_default();
        css.load_from_path( Utils.find_asset( "athena.css" ) );
        Gtk.StyleContext.add_provider_for_screen( screen, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION );

        var window = new MainWindow( this );
        window.show_all();
        this.window = window;
    }

    /**
     * Activates the application.
     *
     * This method is invoked whenever the application is called without opening files.
     * If the application was just started, then this method will reload the current session.
     * Otherwise, it will only bring the window to foreground.
     */
    public override void activate()
    {
        if( activated ) window.present();
        else
        {
            activated = true;
            process_events();
            window.reload_session( true );
        }
    }

    /**
     * Opens the given `files` within the primary application instance.
     *
     * This method is invoked whenever the application is called with files being passed as command line arguments.
     * If the application was just started, then this method will start a new intermediate session.
     * Otherwise, the files will be opened within the current session.
     */
    public override void open( File[] files, string hint )
    {
        if( !activated )
        {
            activated = true;
            window.start_new_session( false );
        }
        process_events();
        foreach( var file in files ) window.editor.open_file_from( file.get_path() );
        window.present();
    }

    public override void show_about( Gtk.Widget parent )
    {
        var dlg = new AboutDialog( parent as Gtk.Window );
        dlg.run();
        dlg.destroy();
    }

    public static void process_events()
    {
        while( Gtk.events_pending() ) Gtk.main_iteration();
    }

    #if DEBUG
    private static bool check_leak( string tag, uint counter )
    {
        if( counter != 0 )
        {
            warning( "!!! %s leaked -- %u time(s)", tag, counter );
            return false;
        }
        else return true;
    }
    #endif

    public static int main( string[] args )
    {
        var app = new Athena();

        Granite.Services.Paths .initialize( "athena-latex-ide", "" );
        Granite.Services.Logger.initialize( Athena.instance.program_name );
        Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;

        var result = app.run( args );

        #if DEBUG
        bool no_leaks = true;

        no_leaks = check_leak(                   "MainWindow",                   MainWindow._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(                       "Editor",                       Editor._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(                      "Session",                      Session._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(            "SourceFileManager",            SourceFileManager._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak( "SourceFileManager.SourceFile", SourceFileManager.SourceFile._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(         "SourceStructure.Node",         SourceStructure.Node._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(               "SourceFileView",               SourceFileView._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(               "PopplerDisplay",               PopplerDisplay._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(              "PopplerRenderer",              PopplerRenderer._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(                   "PdfPreview",                   PdfPreview._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(                 "BuildLogView",                 BuildLogView._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(                   "SessionXml",                   SessionXml._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(   "AnimationControl.Animation",   AnimationControl.Animation._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(   "            SettingsDialog",               SettingsDialog._debug_instance_counter ) && no_leaks;

        if( no_leaks ) info( "No memory leaks detected :)" );
        #endif

        return result;
    }

}
