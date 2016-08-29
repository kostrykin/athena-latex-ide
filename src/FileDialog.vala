class FileDialog : Gtk.FileChooserDialog
{

    private FileDialog()
    {
        this.add_button( "_Cancel", Gtk.ResponseType.CANCEL );
        this.set_default_response ( Gtk.ResponseType.ACCEPT );
    }

    private string? exec()
    {
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

    public static string? choose_readable_file( Gtk.Window? parent )
    {
        var dlg = new FileDialog();
        dlg.title = "Open File";
        dlg.add_button( "_Open", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.OPEN;
        dlg.set_transient_for( parent );
        return dlg.exec();
    }

    public static string? choose_writable_file( Gtk.Window? parent )
    {
        var dlg = new FileDialog();
        dlg.title = "Save File";
        dlg.add_button( "_Save", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.SAVE;
        dlg.do_overwrite_confirmation = true;
        dlg.set_transient_for( parent );
        return dlg.exec();
    }

    public static string? choose_directory( Gtk.Window? parent )
    {
        var dlg = new FileDialog();
        dlg.title = "Choose Directory";
        dlg.add_button( "_Choose", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.SELECT_FOLDER;
        dlg.set_transient_for( parent );
        return dlg.exec();
    }

    public static bool choose_readable_file_and( Gtk.Window? parent, PathHandler handle )
    {
        string? path = choose_readable_file( parent );
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

    public static bool choose_writable_file_and( Gtk.Window? parent, PathHandler handle )
    {
        string? path = choose_writable_file( parent );
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

    public static bool choose_directory_and( Gtk.Window? parent, PathHandler handle )
    {
        string? path = choose_directory( parent );
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
