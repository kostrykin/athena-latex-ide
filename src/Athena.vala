public class Athena : Granite.Application
{

    construct
    {
        application_id = "simple.granite.org";
        program_name   = "Athena";
        app_years      = "2016";
        
        build_version = "0.1";
        app_icon      = "athena";
        main_url      = "https://launchpad.net/granite";
        bug_url       = "https://bugs.launchpad.net/granite";
        help_url      = "https://answers.launchpad.net/granite";
        translate_url = "https://translations.launchpad.net/granite";
        about_authors = {
            "Leonid Kostrykin <void@evoid.de>", null
        };

        about_comments     = "Streamlined LaTeX IDE";
        about_translators  = "Launchpad Translators";
        about_license_type = Gtk.License.GPL_2_0;
    }

    public override void activate()
    {
        var css    = new Gtk.CssProvider();
        var screen = Gdk.Screen.get_default();
        css.load_from_path( "athena.css" );
        Gtk.StyleContext.add_provider_for_screen( screen, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION );

        var window = new MainWindow( this );
        window.destroy.connect( Gtk.main_quit );
        window.show_all();
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
        new Athena().run( args );
        Gtk.main();

        #if DEBUG
        bool no_leaks = true;

        no_leaks = check_leak(           "MainWindow",           MainWindow._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(               "Editor",               Editor._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak( "SourceStructure.Node", SourceStructure.Node._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(       "SourceFileView",       SourceFileView._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(       "PopplerDisplay",       PopplerDisplay._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(      "PopplerRenderer",      PopplerRenderer._debug_instance_counter ) && no_leaks;
        no_leaks = check_leak(           "PdfPreview",           PdfPreview._debug_instance_counter ) && no_leaks;

        if( no_leaks ) stdout.printf( "+ no memory leaks detected +\n" );
        #endif

        return 0;
    }

}
