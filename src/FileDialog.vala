class FileDialog : Gtk.FileChooserDialog
{

    private static Gee.Map< string, string > last_folders = new Gee.HashMap< string, string >();
    private string context;

    private FileDialog( string context )
    {
        this.context = context;
        this.add_button( "_Cancel", Gtk.ResponseType.CANCEL );
        this.set_default_response ( Gtk.ResponseType.ACCEPT );
    }

    public override void response( int type )
    {
        if( type == Gtk.ResponseType.ACCEPT )
        {
            last_folders[ context] = get_current_folder();
        }
    }

    private string? exec()
    {
        if( context in last_folders )
        {
            this.set_current_folder( last_folders[ context ] );
        }
        var result = this.run();
        if( result == Gtk.ResponseType.ACCEPT )
        {
            var path = this.get_filename();
            this.destroy();
            return path;
        }
        else
        {
            this.destroy();
            return null;
        }
    }

    public delegate void PathHandler( string path );

    public static string? choose_readable_file( string context = "" )
    {
        var dlg = new FileDialog( context );
        dlg.title = "Open File";
        dlg.add_button( "_Open", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.OPEN;
        return dlg.exec();
    }

    public static string? choose_writable_file( string context = "" )
    {
        var dlg = new FileDialog( context );
        dlg.title = "Save File";
        dlg.add_button( "_Save", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.SAVE;
        return dlg.exec();
    }

    public static bool choose_readable_file_and( PathHandler handle, string context = "" )
    {
        string? path = choose_readable_file( context );
        if( path == null )
        {      
            return false;
        }
        else
        {
            handle( path );
            return true;
        }
    }

    public static bool choose_writable_file_and( PathHandler handle, string context = "" )
    {
        string? path = choose_writable_file( context );
        if( path == null )
        {      
            return false;
        }
        else
        {
            handle( path );
            return true;
        }
    }

}
