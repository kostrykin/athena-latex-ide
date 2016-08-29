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

    public void apply_dialog_style( Gtk.Dialog dlg )
    {
        dlg.resizable    = false;
        dlg.deletable    = false;
        dlg.border_width = 5;
    }

    public bool is_contained_within( Gtk.Widget parent, Gtk.Widget descendant )
    {
        if( descendant.get_parent() == parent ) return true;
        else
        if( descendant.get_parent() != null ) return is_contained_within( parent, descendant.get_parent() );
        else return false;
    }

    /**
     * Finds the first occasion of a file, whose name matches the `filename_pattern`, or `null`, if no such file exists.
     *
     * Also returns `null` if `base_dir_path` does not exist or doesn't refer to a readable directory.
     */
    public string? find_file( string base_dir_path, Regex filename_pattern, bool recursive )
    {
        try
        {
            Dir dir = Dir.open( base_dir_path, 0 );
            unowned string? filename;
            while( ( filename = dir.read_name() ) != null )
            {
                var entry  = Path.build_path( Path.DIR_SEPARATOR_S, base_dir_path, filename );
                var is_dir = FileUtils.test( entry, FileTest.IS_DIR );
                var inner_result = is_dir && recursive ? find_file( entry, filename_pattern, recursive ) : null;
                if( inner_result == null )
                {
                    MatchInfo match;
                    filename_pattern.match( filename, 0, out match );
                    if( match.matches() ) return entry;
                }
                else return inner_result;
            }
            return null;
        }
        catch( FileError err )
        {
            warning( "Failed to read directory: %s\n", base_dir_path );
            return null;
        }
    }

    public string find_file_by_exact_name( string base_dir_path, string filename, bool recursive )
    {
        var pattern = new Regex( Regex.escape_string( filename ) );
        return find_file( base_dir_path, pattern, recursive );
    }

    public string read_text_file( File file )
    {
        bool first_line = true;
        string line;
        var data  = new StringBuilder();
        var input = new DataInputStream( file.read() );
        while( ( line = input.read_line( null ) ) != null )
        {
            data.append( ( first_line ? "%s" : "\n%s" ).printf( line ) );
            first_line = false;
        }
        return data.str;
    }

    public string? find_asset( string asset_name )
    {
        var assets_dir = Path.build_path( Path.DIR_SEPARATOR_S, Environment.get_current_dir(), "assets" );
        string[] search_dirs = { assets_dir, Path.build_path( Path.DIR_SEPARATOR_S, get_install_prefix(), "share/athena-latex-ide" ) };

        foreach( string search_dir in search_dirs )
        {
            if( !FileUtils.test( search_dir, FileTest.IS_DIR | FileTest.EXISTS ) ) continue;
            var result = find_file_by_exact_name( search_dir, asset_name, true );
            if( result != null ) return result;
        }

        warning( "Couldn't find asset: %s", asset_name );
        return null;
    }

    extern unowned string get_install_prefix();

    extern unowned string get_version();

    public static string resolve_home_dir( string path )
    {
        if( path.has_prefix( "~" ) ) return Path.build_path( Path.DIR_SEPARATOR_S, Environment.get_home_dir(), path.substring( 1 ) );
        else return path;
    }

}
