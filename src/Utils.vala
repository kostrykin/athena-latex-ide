namespace Utils
{

    public static int min( int a, int b )
    {
        return a < b ? a : b;
    }

    public static int max( int a, int b )
    {
        return a > b ? a : b;
    }

    public static double mind( double a, double b )
    {
        return a < b ? a : b;
    }

    public static double maxd( double a, double b )
    {
        return a > b ? a : b;
    }

    /**
     * Tells, whether `primary_path` and `secondary_path` point to the same file.
     *
     * Note that this function isn't symmetric w.r.t. its arguments:
     *
     *  - If querying info for `primary_path` fails, an error is thrown.
     *  - But if querying info for `secondary_path` fails, simply `false` is returned.
     */
    public static bool same_files( string primary_path, string secondary_path ) throws Error
    {
        var file1 = GLib.File.new_for_path( primary_path );
        var file2 = GLib.File.new_for_path( secondary_path );
        if( file1.equal( file2 ) )
        {
            return true;
        }
        else
        {
            var info1 = file1.query_info( FileAttribute.ID_FILE, FileQueryInfoFlags.NONE );
            FileInfo? info2 = null;
            try
            {
                info2 = file2.query_info( FileAttribute.ID_FILE, FileQueryInfoFlags.NONE );
            }
            catch( Error err )
            {
                return false;
            }
            var id1 = info1.get_attribute_as_string( FileAttribute.ID_FILE );
            var id2 = info2.get_attribute_as_string( FileAttribute.ID_FILE );
            return id1 == id2;
        }
    }

    public string format_hotkey( owned string hotkey )
    {
        hotkey = hotkey.replace( "<Control>", "Ctrl+" );
        return "[%s]".printf( hotkey );
    }

}
