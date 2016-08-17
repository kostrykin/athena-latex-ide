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

    public static bool same_files( string path1, string path2 )
    {
        var file1 = GLib.File.new_for_path( path1 );
        var file2 = GLib.File.new_for_path( path2 );
        if( file1.equal( file2 ) )
        {
            return true;
        }
        else
        {
            var info1 = file1.query_info( FileAttribute.ID_FILE, FileQueryInfoFlags.NONE );
            var info2 = file2.query_info( FileAttribute.ID_FILE, FileQueryInfoFlags.NONE );
            var id1 = info1.get_attribute_as_string( FileAttribute.ID_FILE );
            var id2 = info2.get_attribute_as_string( FileAttribute.ID_FILE );
            return id1 == id2;
        }
    }

}
