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

    public static string? choose_readable_file()
    {
        var dlg = new FileDialog();
        dlg.title = "Open File";
        dlg.add_button( "_Open", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.OPEN;
        return dlg.exec();
    }

    public static string? choose_writable_file()
    {
        var dlg = new FileDialog();
        dlg.title = "Save File";
        dlg.add_button( "_Save", Gtk.ResponseType.ACCEPT );
        dlg.action = Gtk.FileChooserAction.SAVE;
        return dlg.exec();
    }

    public static bool choose_readable_file_and( PathHandler handle )
    {
        string? path = choose_readable_file();
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

    public static bool choose_writable_file_and( PathHandler handle )
    {
        string? path = choose_writable_file();
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
